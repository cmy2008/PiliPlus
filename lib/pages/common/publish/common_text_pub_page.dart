import 'package:PiliPlus/pages/common/publish/common_publish_page.dart';
import 'package:PiliPlus/utils/feed_back.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:PiliPlus/models/common/publish_panel_type.dart';

abstract class CommonTextPubPage extends CommonPublishPage<String> {
  const CommonTextPubPage({
    super.key,
    super.initialValue,
    super.onSave,
  });
}

abstract class CommonTextPubPageState<T extends CommonTextPubPage>
    extends CommonPublishPageState<T> {
  @override
  late final TextEditingController editController = TextEditingController(
    text: widget.initialValue,
  );

  @override
  void initPubState() {
    if (widget.initialValue?.trim().isNotEmpty == true) {
      enablePublish.value = true;
    }
  }

  @override
  void onSave() => widget.onSave?.call(editController.text);

  @override
  Future<void> onPublish() {
    feedBack();
    return onCustomPublish();
  }

  Widget get customPanelBtn => Obx(
        () {
          final isCustom = panelType.value == PanelType.custom;
          return IconButton(
            tooltip: isCustom ? '输入' : '自定义',
            onPressed: () {
              if (isCustom) {
                updatePanelType(PanelType.keyboard);
              } else {
                updatePanelType(PanelType.custom);
              }
            },
            icon: isCustom
                ? const Icon(Icons.keyboard, size: 22)
                : const Icon(Icons.list_alt, size: 22),
            color: isCustom ? Theme.of(context).colorScheme.primary : null,
          );
        },
      );
}
