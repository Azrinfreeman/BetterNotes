import 'package:flutter/material.dart';

import 'theme/notes_theme.dart';

class SettingsSection {
  const SettingsSection(this.title, this.icon, this.children);
  final String title;
  final IconData icon;
  final List<Widget> children;
}

/// All options remain on one page; wide layouts add direct section navigation.
class SettingsSections extends StatefulWidget {
  const SettingsSections({super.key, required this.sections});
  final List<SettingsSection> sections;
  @override
  State<SettingsSections> createState() => _SettingsSectionsState();
}

class _SettingsSectionsState extends State<SettingsSections> {
  final _keys = <String, GlobalKey>{};
  final _scroll = ScrollController();
  int _active = 0;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide =
          constraints.maxWidth >= 1000 &&
          MediaQuery.textScalerOf(context).scale(1) <= 1.5;
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (wide)
            SizedBox(
              width: 232,
              child: ColoredBox(
                color: NotesColors.of(context).sidebar,
                child: ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    for (var i = 0; i < widget.sections.length; i++)
                      ListTile(
                        leading: Icon(widget.sections[i].icon),
                        title: Text(widget.sections[i].title),
                        selected: _active == i,
                        onTap: () {
                          setState(() => _active = i);
                          final target =
                              _keys[widget.sections[i].title]?.currentContext;
                          if (target != null) Scrollable.ensureVisible(target);
                        },
                      ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
              controller: _scroll,
              padding: EdgeInsets.all(wide ? 24 : 16),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 780),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final section in widget.sections)
                        Padding(
                          key: _keys.putIfAbsent(section.title, GlobalKey.new),
                          padding: const EdgeInsets.only(bottom: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
                                child: Semantics(
                                  header: true,
                                  child: Text(
                                    section.title,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium,
                                  ),
                                ),
                              ),
                              Material(
                                color: Theme.of(context).colorScheme.surface,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: section.children,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}
