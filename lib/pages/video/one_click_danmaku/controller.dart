import 'dart:ui' show Color;

import 'package:flutter/material.dart' show TextEditingController;
import 'package:PiliPlus/grpc/bilibili/community/service/dm/v1.pb.dart'
    show DanmakuElem, DmColorfulType, DmSegMobileReply;
import 'package:PiliPlus/grpc/dm.dart' show DmGrpc;
import 'package:PiliPlus/http/danmaku.dart' show DanmakuHttp;
import 'package:PiliPlus/http/loading_state.dart' show Success;
import 'package:PiliPlus/pages/danmaku/controller.dart' show PlDanmakuController;
import 'package:PiliPlus/pages/danmaku/danmaku_model.dart'
    show DanmakuExtra, VideoDanmaku;
import 'package:PiliPlus/plugin/pl_player/controller.dart'
    show PlPlayerController;
import 'package:PiliPlus/utils/storage_utils.dart' show StorageUtils;
import 'package:canvas_danmaku/canvas_danmaku.dart'
    show DanmakuContentItem, DanmakuItemType;
import 'package:file_picker/file_picker.dart' show FilePicker, FileType;
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';

class DanmakuEntry {
  final int progress;
  final String content;
  final int color;
  final int mode;
  final int fontsize;
  final bool isColorful;

  DanmakuEntry({
    required this.progress,
    required this.content,
    required this.color,
    this.mode = 1,
    this.fontsize = 25,
    this.isColorful = false,
  });

  factory DanmakuEntry.fromDanmakuElem(DanmakuElem elem) {
    return DanmakuEntry(
      progress: elem.progress,
      content: elem.content,
      color: elem.color,
      mode: elem.mode,
      fontsize: elem.fontsize,
      isColorful: elem.colorful == DmColorfulType.VipGradualColor,
    );
  }
}

class OneClickDanmakuController extends GetxController {
  final PlPlayerController plPlayerController;
  final int cid;
  final String bvid;

  OneClickDanmakuController({
    required this.plPlayerController,
    required this.cid,
    required this.bvid,
  }) {
    jumpRangeController = TextEditingController(text: jumpRange.value.toString());
  }

  @override
  void onClose() {
    jumpRangeController.dispose();
    super.onClose();
  }

  final RxList<DanmakuEntry> _allEntries = <DanmakuEntry>[].obs;
  List<DanmakuEntry> get allEntries => _allEntries;

  final RxInt currentPage = 1.obs;
  final RxDouble jumpRange = 10.0.obs;
  late final TextEditingController jumpRangeController;
  static const int pageSize = 10;

  int get totalPages {
    final count = _allEntries.length;
    if (count == 0) return 1;
    return (count - 1) ~/ pageSize + 1;
  }

  int get totalCount => _allEntries.length;
  bool get isEmpty => _allEntries.isEmpty;

  List<DanmakuEntry> get currentPageEntries {
    if (_allEntries.isEmpty) return [];
    final start = (currentPage.value - 1) * pageSize;
    final end = start + pageSize;
    return _allEntries.sublist(start, end.clamp(0, _allEntries.length));
  }

  void removeEntry(DanmakuEntry entry) {
    _allEntries.remove(entry);
    final maxPage = totalPages;
    if (currentPage.value > maxPage) {
      currentPage.value = maxPage < 1 ? 1 : maxPage;
    }
  }

  void prevPage() {
    if (currentPage.value > 1) {
      currentPage.value--;
    }
  }

  void nextPage() {
    if (currentPage.value < totalPages) {
      currentPage.value++;
    }
  }

  Future<void> importDanmaku() async {
    final result = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['pb', 'bin', 'json'],
    );
    if (result == null) return;
    try {
      final bytes = await result.xFile.readAsBytes();
      if (bytes.isEmpty) {
        SmartDialog.showToast('文件为空');
        return;
      }
      DmSegMobileReply reply;
      try {
        reply = DmSegMobileReply.fromBuffer(bytes);
      } catch (_) {
        try {
          final text = await result.xFile.readAsString();
          reply = DmSegMobileReply.fromJson(text);
        } catch (_) {
          SmartDialog.showToast('文件格式不正确');
          return;
        }
      }
      if (reply.elems.isEmpty) {
        SmartDialog.showToast('文件中无弹幕数据');
        return;
      }
      reply.elems.sort((a, b) => a.progress.compareTo(b.progress));
      _allEntries.clear();
      for (final elem in reply.elems) {
        _allEntries.add(DanmakuEntry.fromDanmakuElem(elem));
      }
      currentPage.value = 1;
      SmartDialog.showToast('已导入 ${_allEntries.length} 条弹幕');
    } catch (_) {
      SmartDialog.showToast('文件格式不正确');
    }
  }

  Future<void> exportDanmaku() async {
    if (cid <= 0) {
      SmartDialog.showToast('当前无弹幕可导出');
      return;
    }
    SmartDialog.showLoading(msg: '获取弹幕数据...');
    try {
      final segments = <DanmakuElem>[];
      final durationMs = plPlayerController.durationInMilliseconds;
      if (durationMs <= 0) {
        SmartDialog.dismiss();
        SmartDialog.showToast('播放器尚未就绪');
        return;
      }
      final totalSegments =
          (durationMs / PlDanmakuController.segmentLength).ceil();
      for (int i = 0; i < totalSegments; i++) {
        final res = await DmGrpc.dmSegMobile(
          cid: cid,
          segmentIndex: i + 1,
        );
        if (res case Success(:final response)) {
          segments.addAll(response.elems);
        }
      }
      if (segments.isEmpty) {
        SmartDialog.dismiss();
        SmartDialog.showToast('当前无弹幕可导出');
        return;
      }
      final reply = DmSegMobileReply(elems: segments);
      final bytes = reply.writeToBuffer();
      SmartDialog.dismiss();
      await StorageUtils.saveBytes2File(
        name:
            'danmaku_${cid}_${DateTime.now().millisecondsSinceEpoch}.pb',
        bytes: bytes,
        allowedExtensions: const ['pb', 'bin'],
      );
    } catch (e) {
      SmartDialog.dismiss();
      SmartDialog.showToast('导出失败: $e');
    }
  }

  Future<void> sendDanmaku(DanmakuEntry entry) async {
    if (plPlayerController.videoPlayerController == null) {
      SmartDialog.showToast('视频未就绪，无法发送');
      return;
    }

    final danmakuTime = entry.progress / 1000.0;
    final currentTime = plPlayerController.positionInMilliseconds / 1000.0;
    final diff = (currentTime - danmakuTime).abs();

    if (diff >= jumpRange.value) {
      await plPlayerController.seekTo(
        Duration(milliseconds: entry.progress),
      );
      await Future.delayed(const Duration(milliseconds: 500));
    }

    final bool isColorful = entry.isColorful;
    final res = await DanmakuHttp.shootDanmaku(
      oid: cid,
      bvid: bvid,
      progress: plPlayerController.positionInMilliseconds,
      msg: entry.content,
      mode: entry.mode,
      fontSize: entry.fontsize,
      color: entry.color & 0xFFFFFF,
      colorful: isColorful,
    );

    if (res case Success(:final response)) {
      SmartDialog.showToast('已发送');
      VideoDanmaku? extra;
      if (response.dmid case final dmid?) {
        extra = VideoDanmaku(
          id: dmid,
          mid: PlPlayerController.instance!.midHash,
        );
      }
      plPlayerController.danmakuController?.addDanmaku(
        DanmakuContentItem(
          entry.content,
          color: isColorful
              ? const Color(0xFFFFFFFF)
              : Color(entry.color | 0xFF000000),
          type: switch (entry.mode) {
            5 => DanmakuItemType.top,
            4 => DanmakuItemType.bottom,
            _ => DanmakuItemType.scroll,
          },
          selfSend: true,
          isColorful: isColorful,
          extra: extra,
        ),
      );
    } else {
      res.toast();
    }
  }
}
