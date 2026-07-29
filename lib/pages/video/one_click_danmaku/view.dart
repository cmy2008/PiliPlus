import 'package:PiliPlus/pages/video/one_click_danmaku/controller.dart';
import 'package:PiliPlus/plugin/pl_player/controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class OneClickDanmakuPanel extends StatelessWidget {
  final PlPlayerController plPlayerController;
  final int cid;
  final String bvid;

  const OneClickDanmakuPanel({
    super.key,
    required this.plPlayerController,
    required this.cid,
    required this.bvid,
  });

  @override
  Widget build(BuildContext context) {
    final controller = Get.isRegistered<OneClickDanmakuController>(
      tag: 'one_click_danmaku_$cid',
    )
        ? Get.find<OneClickDanmakuController>(
            tag: 'one_click_danmaku_$cid',
          )
        : Get.put<OneClickDanmakuController>(
            OneClickDanmakuController(
              plPlayerController: plPlayerController,
              cid: cid,
              bvid: bvid,
            ),
            tag: 'one_click_danmaku_$cid',
          );
    final themeData = Theme.of(context);
    final colorScheme = themeData.colorScheme;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      decoration: BoxDecoration(
        color: themeData.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Column(
        children: [
          _buildTitle(context, colorScheme, controller),
          _buildActionBar(context, colorScheme, controller),
          _buildJumpRange(context, colorScheme, controller),
          const Divider(height: 1),
          Expanded(child: _buildDanmakuList(context, controller, colorScheme)),
          _buildPagination(context, controller, colorScheme),
        ],
      ),
    );
  }

  Widget _buildTitle(
    BuildContext context,
    ColorScheme colorScheme,
    OneClickDanmakuController controller,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
      child: Row(
        children: [
          Text(
            '一键发送弹幕',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.close, size: 20, color: colorScheme.onSurfaceVariant),
            onPressed: Get.back,
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar(
    BuildContext context,
    ColorScheme colorScheme,
    OneClickDanmakuController controller,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          _actionButton('导入', () => controller.importDanmaku(), colorScheme),
          const SizedBox(width: 8),
          _actionButton('导出', () => controller.exportDanmaku(), colorScheme),
          const SizedBox(width: 8),
          Obx(() => _actionButton(
            '保存待发送',
            controller.isEmpty ? null : () => controller.saveDanmaku(),
            colorScheme,
          )),
        ],
      ),
    );
  }

  Widget _actionButton(
    String label,
    VoidCallback? onTap,
    ColorScheme colorScheme,
  ) {
    return SizedBox(
      height: 32,
      child: TextButton(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          foregroundColor: onTap != null ? colorScheme.onSurfaceVariant : colorScheme.outline,
          disabledForegroundColor: colorScheme.outline,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.3)),
          ),
        ),
        onPressed: onTap,
        child: Text(label, style: const TextStyle(fontSize: 12)),
      ),
    );
  }

  Widget _buildJumpRange(
    BuildContext context,
    ColorScheme colorScheme,
    OneClickDanmakuController controller,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Text('跳转范围', style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant)),
          const SizedBox(width: 8),
          SizedBox(
            width: 72,
            height: 30,
            child: TextField(
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(fontSize: 13, color: colorScheme.onSurface),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: colorScheme.outline.withValues(alpha: 0.3)),
                ),
                suffixText: 's',
                suffixStyle: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
              ),
              controller: controller.jumpRangeController,
              onChanged: (v) {
                final val = double.tryParse(v);
                if (val != null && val >= 0) {
                  controller.jumpRange.value = val;
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDanmakuList(
    BuildContext context,
    OneClickDanmakuController controller,
    ColorScheme colorScheme,
  ) {
    return Obx(() {
      if (controller.isEmpty) {
        return Center(
          child: Text(
            '无弹幕可发送',
            style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
          ),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Text(
              '发送弹幕列表  页 ${controller.currentPage.value}/${controller.totalPages}',
              style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: controller.currentPageEntries.length,
              separatorBuilder: (_, _) => Divider(height: 1, color: colorScheme.outline.withValues(alpha: 0.08)),
              itemBuilder: (context, index) {
                final entry = controller.currentPageEntries[index];
                return _buildDanmakuItem(context, controller, entry, colorScheme);
              },
            ),
          ),
        ],
      );
    });
  }

  Widget _buildDanmakuItem(
    BuildContext context,
    OneClickDanmakuController controller,
    DanmakuEntry entry,
    ColorScheme colorScheme,
  ) {
    final timeStr = _formatTime(entry.progress);
    final color = Color(entry.color | 0xFF000000);
    final text = entry.content;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Text(
              timeStr,
              style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
            ),
          ),
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Tooltip(
              message: text,
              child: Text(
                text,
                style: TextStyle(fontSize: 13, color: colorScheme.onSurface),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 28,
            child: TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                  side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.4)),
                ),
              ),
              onPressed: () => controller.sendDanmaku(entry),
              child: Text(
                '发送',
                style: TextStyle(fontSize: 12, color: colorScheme.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPagination(
    BuildContext context,
    OneClickDanmakuController controller,
    ColorScheme colorScheme,
  ) {
    return Obx(() {
      if (controller.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _pageButton('上一页', controller.currentPage.value > 1
                ? () => controller.prevPage() : null, colorScheme),
            const SizedBox(width: 16),
            Text(
              '${controller.currentPage.value} / ${controller.totalPages}',
              style: TextStyle(fontSize: 14, color: colorScheme.onSurface),
            ),
            const SizedBox(width: 16),
            _pageButton('下一页', controller.currentPage.value < controller.totalPages
                ? () => controller.nextPage() : null, colorScheme),
          ],
        ),
      );
    });
  }

  Widget _pageButton(String label, VoidCallback? onTap, ColorScheme colorScheme) {
    return SizedBox(
      height: 28,
      child: TextButton(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          foregroundColor: onTap != null ? colorScheme.onSurface : colorScheme.outline,
          disabledForegroundColor: colorScheme.outline,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.3)),
          ),
        ),
        onPressed: onTap,
        child: Text(label, style: const TextStyle(fontSize: 12)),
      ),
    );
  }

  String _formatTime(int progressMs) {
    final totalSec = progressMs ~/ 1000;
    final minutes = totalSec ~/ 60;
    final seconds = totalSec % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
