import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';
import 'package:stac/stac.dart';


typedef BrixtaUiRunAction =
    Future<void> Function(
      Map<String, dynamic> action,
    );


class BrixtaUiRuntime {
  const BrixtaUiRuntime({
    required this.record,
    required this.stateId,
    required this.actions,
    required this.submittingActionKey,
    required this.onRunAction,
    this.onRefresh,
  });

  final Map<String, dynamic>? record;
  final String? stateId;

  final List<Map<String, dynamic>>
  actions;

  final String?
  submittingActionKey;

  final BrixtaUiRunAction
  onRunAction;

  final Future<void> Function()?
  onRefresh;


  Map<String, dynamic>
  get payload {
    final raw =
        record?['payload'];

    return raw is Map
        ? Map<String, dynamic>.from(
            raw,
          )
        : <String, dynamic>{};
  }


  Map<String, dynamic>
  get computed {
    final raw =
        payload['__computed'];

    return raw is Map
        ? Map<String, dynamic>.from(
            raw,
          )
        : <String, dynamic>{};
  }


  Map<String, dynamic>
  get contextValues {
    final raw =
        payload['__context'];

    return raw is Map
        ? Map<String, dynamic>.from(
            raw,
          )
        : <String, dynamic>{};
  }


  Map<String, dynamic>
  get stateValues {
    final raw =
        payload['__state'];

    return raw is Map
        ? Map<String, dynamic>.from(
            raw,
          )
        : <String, dynamic>{};
  }


  dynamic resolveBinding(
    dynamic raw,
  ) {
    if (
      raw is! Map
    ) {
      return null;
    }

    final binding =
        Map<String, dynamic>.from(
          raw,
        );

    final scope =
        binding['scope']
            ?.toString();

    final key =
        binding['key']
            ?.toString();

    switch (scope) {
      case 'literal':
        return binding[
          'value'
        ];

      case 'capture':
        return key == null
            ? null
            : payload[
                key
              ];

      case 'computed':
        if (
          key == null
        ) {
          return null;
        }

        return computed[
              key
            ] ??
            payload[
              key
            ];

      case 'context':
        return key == null
            ? null
            : contextValues[
                key
              ];

      case 'state':
        if (
          key == null ||
          key == 'process'
        ) {
          return stateId;
        }

        return stateValues[
              key
            ] ??
            (
              key == 'process'
                  ? stateId
                  : null
            );

      case 'record':
        if (
          key == null
        ) {
          return record;
        }

        return record?[
          key
        ];

      case 'actor':
        return contextValues[
          key
        ];

      default:
        return null;
    }
  }


  bool isVisible(
    dynamic raw,
  ) {
    if (
      raw == null
    ) {
      return true;
    }

    if (
      raw is! Map
    ) {
      return true;
    }

    final visibility =
        Map<String, dynamic>.from(
          raw,
        );

    final left =
        resolveBinding(
          visibility[
            'binding'
          ],
        );

    final operator =
        visibility[
          'operator'
        ]?.toString() ??
        'eq';

    final right =
        visibility[
          'value'
        ];

    switch (operator) {
      case 'exists':
        return left != null &&
            left != '';

      case 'not_exists':
        return left == null ||
            left == '';

      case 'neq':
        return left != right;

      case 'gt':
        return _number(
              left,
            ) >
            _number(
              right,
            );

      case 'gte':
        return _number(
              left,
            ) >=
            _number(
              right,
            );

      case 'lt':
        return _number(
              left,
            ) <
            _number(
              right,
            );

      case 'lte':
        return _number(
              left,
            ) <=
            _number(
              right,
            );

      case 'eq':
      default:
        return left == right;
    }
  }


  static double _number(
    dynamic value,
  ) {
    if (
      value is num
    ) {
      return value
          .toDouble();
    }

    return double.tryParse(
          value?.toString() ??
              '',
        ) ??
        0;
  }
}


class BrixtaUiRuntimeScope
    extends InheritedWidget {
  const BrixtaUiRuntimeScope({
    super.key,
    required this.runtime,
    required super.child,
  });

  final BrixtaUiRuntime
  runtime;


  static BrixtaUiRuntime of(
    BuildContext context,
  ) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<
          BrixtaUiRuntimeScope
        >();

    assert(
      scope != null,
      'BrixtaUiRuntimeScope missing.',
    );

    return scope!.runtime;
  }


  @override
  bool updateShouldNotify(
    BrixtaUiRuntimeScope oldWidget,
  ) {
    return true;
  }
}


/**
 * Stac custom parser.
 *
 * Stac remains the JSON -> Widget entry point.
 * BRIXTA owns only the app-specific binding/action semantics.
 */
class BrixtaScreenParser
    extends StacParser<
      Map<String, dynamic>
    > {
  const BrixtaScreenParser();


  @override
  String get type =>
      'brixtaScreen';


  @override
  Map<String, dynamic>
  getModel(
    Map<String, dynamic> json,
  ) {
    return json;
  }


  @override
  Widget parse(
    BuildContext context,
    Map<String, dynamic> model,
  ) {
    final runtime =
        BrixtaUiRuntimeScope.of(
          context,
        );

    final raw =
        model['document'];

    final document =
        raw is Map
        ? Map<String, dynamic>.from(
            raw,
          )
        : <String, dynamic>{};

    return _BrixtaDocumentView(
      document:
          document,

      runtime:
          runtime,
    );
  }
}


class BrixtaStacUi
    extends StatelessWidget {
  const BrixtaStacUi({
    super.key,
    required this.document,
    required this.record,
    required this.stateId,
    required this.actions,
    required this.submittingActionKey,
    required this.onRunAction,
    this.onRefresh,
  });

  final Map<String, dynamic>
  document;

  final Map<String, dynamic>?
  record;

  final String?
  stateId;

  final List<Map<String, dynamic>>
  actions;

  final String?
  submittingActionKey;

  final BrixtaUiRunAction
  onRunAction;

  final Future<void> Function()?
  onRefresh;


  @override
  Widget build(
    BuildContext context,
  ) {
    final runtime =
        BrixtaUiRuntime(
          record:
              record,

          stateId:
              stateId,

          actions:
              actions,

          submittingActionKey:
              submittingActionKey,

          onRunAction:
              onRunAction,

          onRefresh:
              onRefresh,
        );

    return BrixtaUiRuntimeScope(
      runtime:
          runtime,

      child:
          Builder(
            builder:
                (
                  innerContext,
                ) {
              return Stac.fromJson(
                    {
                      'type':
                          'brixtaScreen',

                      'document':
                          document,
                    },

                    innerContext,
                  ) ??
                  const SizedBox.shrink();
            },
          ),
    );
  }
}


class _BrixtaDocumentView
    extends StatelessWidget {
  const _BrixtaDocumentView({
    required this.document,
    required this.runtime,
  });

  final Map<String, dynamic>
  document;

  final BrixtaUiRuntime
  runtime;


  List<Map<String, dynamic>>
  get blocks {
    final raw =
        document[
          'blocks'
        ];

    if (
      raw is! List
    ) {
      return const [];
    }

    return raw
        .whereType<
          Map
        >()
        .map(
          (
            item,
          ) =>
              Map<String, dynamic>.from(
                item,
              ),
        )
        .toList();
  }


  Map<String, Map<String, dynamic>>
  get byId {
    return {
      for (
        final block
        in blocks
      )
        if (
          block['id'] !=
          null
        )
          block[
            'id'
          ].toString():
              block,
    };
  }


  List<String>
  get rootIds {
    final raw =
        document[
          'rootIds'
        ];

    if (
      raw is! List
    ) {
      return const [];
    }

    return raw
        .map(
          (
            item,
          ) =>
              item.toString(),
        )
        .toList();
  }


  @override
  Widget build(
    BuildContext context,
  ) {
    final map =
        byId;

    final normal =
        <Widget>[];

    final overlays =
        <Widget>[];


    for (
      final id
      in rootIds
    ) {
      final block =
          map[
            id
          ];

      if (
        block == null
      ) {
        continue;
      }

      if (
        !runtime.isVisible(
          block[
            'visibility'
          ],
        )
      ) {
        continue;
      }

      final type =
          block[
            'type'
          ]?.toString() ??
          '';

      final widget =
          _renderBlock(
            context,
            block,
            map,
          );

      if (
        type ==
        'overlay.fullscreen'
      ) {
        overlays.add(
          Positioned.fill(
            child:
                widget,
          ),
        );
      } else {
        normal.add(
          widget,
        );
      }
    }


    final scroll =
        ListView(
          physics:
              const AlwaysScrollableScrollPhysics(),

          padding:
              const EdgeInsets.fromLTRB(
                24,
                24,
                24,
                48,
              ),

          children: [
            ...normal,

            if (
              normal.isEmpty
            )
              const SizedBox(
                height:
                    420,

                child:
                    Center(
                      child:
                          Text(
                            'This app has no visible UI blocks yet.',
                          ),
                    ),
              ),
          ],
        );


    final content =
        runtime.onRefresh ==
        null
        ? scroll
        : RefreshIndicator(
            onRefresh:
                runtime.onRefresh!,

            child:
                scroll,
          );


    return Stack(
      fit:
          StackFit.expand,

      children: [
        content,
        ...overlays,
      ],
    );
  }


  Widget _renderBlock(
    BuildContext context,
    Map<String, dynamic> block,
    Map<String, Map<String, dynamic>>
    blockMap,
  ) {
    final type =
        block[
          'type'
        ]?.toString() ??
        '';

    final config =
        block[
          'config'
        ] is Map
        ? Map<String, dynamic>.from(
            block[
              'config'
            ] as Map,
          )
        : <String, dynamic>{};

    final childIds =
        block[
          'children'
        ] is List
        ? (
            block[
                  'children'
                ]
                as List
          )
              .map(
                (
                  child,
                ) =>
                    child.toString(),
              )
              .toList()
        : const <
            String
          >[];


    Widget rendered;


    switch (type) {
      case 'layout.column':
        rendered =
            Column(
              crossAxisAlignment:
                  _crossAxis(
                    config[
                      'alignment'
                    ],
                  ),

              children:
                  _children(
                    context,
                    childIds,
                    blockMap,
                    vertical:
                        true,
                    gap:
                        _double(
                          config[
                            'gap'
                          ],
                          16,
                        ),
                  ),
            );

        break;


      case 'layout.row':
        rendered =
            Row(
              crossAxisAlignment:
                  CrossAxisAlignment.center,

              children:
                  _children(
                    context,
                    childIds,
                    blockMap,
                    vertical:
                        false,
                    gap:
                        _double(
                          config[
                            'gap'
                          ],
                          12,
                        ),
                  ),
            );

        break;


      case 'layout.stack':
        rendered =
            Stack(
              children:
                  childIds
                      .map(
                        (
                          id,
                        ) {
                          final child =
                              blockMap[
                                id
                              ];

                          if (
                            child ==
                                null ||
                            !runtime.isVisible(
                              child[
                                'visibility'
                              ],
                            )
                          ) {
                            return const SizedBox.shrink();
                          }

                          return _renderBlock(
                            context,
                            child,
                            blockMap,
                          );
                        },
                      )
                      .toList(),
            );

        break;


      case 'display.text':
        rendered =
            _textWidget(
              config[
                'text'
              ]?.toString() ??
                  '',

              config,
            );

        break;


      case 'display.value':
      case 'display.counter':
      case 'display.metric':
        final value =
            runtime.resolveBinding(
              block[
                'binding'
              ],
            );

        final prefix =
            config[
              'prefix'
            ]?.toString() ??
            '';

        final suffix =
            config[
              'suffix'
            ]?.toString() ??
            '';

        rendered =
            _textWidget(
              '$prefix${_display(value)}$suffix',

              {
                ...config,

                if (
                  type ==
                  'display.counter'
                )
                  'size':
                      config[
                        'size'
                      ] ??
                      'hero',

                if (
                  type ==
                  'display.metric'
                )
                  'size':
                      config[
                        'size'
                      ] ??
                      'large',
              },
            );

        break;


      case 'display.progress':
        final value =
            _double(
              runtime.resolveBinding(
                block[
                  'binding'
                ],
              ),
              0,
            );

        final min =
            _double(
              config[
                'min'
              ],
              0,
            );

        final max =
            _double(
              config[
                'max'
              ],
              100,
            );

        final normalized =
            max <= min
            ? 0.0
            : (
                (
                      value -
                      min
                    ) /
                    (
                      max -
                      min
                    )
              ).clamp(
                0.0,
                1.0,
              );

        rendered =
            LinearProgressIndicator(
              value:
                  normalized,
              minHeight:
                  10,
              borderRadius:
                  BorderRadius.circular(
                    999,
                  ),
            );

        break;


      case 'display.badge':
        final value =
            runtime.resolveBinding(
              block[
                'binding'
              ],
            );

        rendered =
            Align(
              alignment:
                  Alignment.centerLeft,

              child:
                  Container(
                    padding:
                        const EdgeInsets.symmetric(
                          horizontal:
                              12,
                          vertical:
                              6,
                        ),

                    decoration:
                        BoxDecoration(
                          color:
                              Theme.of(
                                context,
                              )
                                  .colorScheme
                                  .secondaryContainer,

                          borderRadius:
                              BorderRadius.circular(
                                999,
                              ),
                        ),

                    child:
                        Text(
                          _display(
                            value,
                          ),
                        ),
                  ),
            );

        break;


      case 'interaction.action_button':
        final actionId =
            block[
              'actionId'
            ]?.toString();

        Map<String, dynamic>?
        action;

        for (
          final candidate
          in runtime.actions
        ) {
          if (
            candidate[
              'key'
            ]?.toString() ==
            actionId
          ) {
            action =
                candidate;
            break;
          }
        }

        final label =
            config[
              'label'
            ]?.toString() ??
            action?[
              'label'
            ]?.toString() ??
            'Continue';

        final busy =
            actionId != null &&
            runtime
                    .submittingActionKey ==
                actionId;

        rendered =
            SizedBox(
              width:
                  double.infinity,

              child:
                  FilledButton(
                    onPressed:
                        action ==
                                null ||
                            busy
                        ? null
                        : () =>
                            unawaited(
                              runtime.onRunAction(
                                action!,
                              ),
                            ),

                    child:
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(
                                vertical:
                                    14,
                              ),

                          child:
                              busy
                              ? const SizedBox(
                                  width:
                                      20,
                                  height:
                                      20,
                                  child:
                                      CircularProgressIndicator(
                                        strokeWidth:
                                            2,
                                      ),
                                )
                              : Text(
                                  label,
                                ),
                        ),
                  ),
            );

        break;


      case 'overlay.banner':
        rendered =
            Container(
              width:
                  double.infinity,

              padding:
                  const EdgeInsets.all(
                    20,
                  ),

              decoration:
                  BoxDecoration(
                    color:
                        Theme.of(
                          context,
                        )
                            .colorScheme
                            .primaryContainer,

                    borderRadius:
                        BorderRadius.circular(
                          20,
                        ),
                  ),

              child:
                  Text(
                    config[
                      'text'
                    ]?.toString() ??
                    '',
                    textAlign:
                        TextAlign.center,
                    style:
                        const TextStyle(
                          fontSize:
                              24,
                          fontWeight:
                              FontWeight.w800,
                        ),
                  ),
            );

        break;


      case 'overlay.fullscreen':
        final background =
            _hexColor(
              config[
                'background'
              ]?.toString(),
            ) ??
            Colors.black;

        final foreground =
            _hexColor(
              config[
                'foreground'
              ]?.toString(),
            ) ??
            Colors.white;

        rendered =
            Material(
              color:
                  background,

              child:
                  SafeArea(
                    child:
                        Center(
                          child:
                              Padding(
                                padding:
                                    const EdgeInsets.all(
                                      28,
                                    ),

                                child:
                                    Text(
                                      config[
                                        'text'
                                      ]?.toString() ??
                                      '',

                                      textAlign:
                                          TextAlign.center,

                                      style:
                                          TextStyle(
                                            color:
                                                foreground,

                                            fontSize:
                                                64,

                                            fontWeight:
                                                FontWeight.w900,

                                            letterSpacing:
                                                -2,
                                          ),
                                    ),
                              ),
                        ),
                  ),
            );

        break;


      case 'media.image':
        final bound =
            runtime.resolveBinding(
              block[
                'binding'
              ],
            );

        final url =
            bound?.toString() ??
            config[
              'url'
            ]?.toString() ??
            '';

        rendered =
            url.startsWith(
              'http',
            )
            ? ClipRRect(
                borderRadius:
                    BorderRadius.circular(
                      18,
                    ),

                child:
                    Image.network(
                      url,
                      fit:
                          BoxFit.cover,
                    ),
              )
            : const SizedBox.shrink();

        break;


      case 'animation.lottie':
        final url =
            config[
              'url'
            ]?.toString() ??
            '';

        final asset =
            config[
              'asset'
            ]?.toString() ??
            '';

        if (
          url.startsWith(
            'http',
          )
        ) {
          rendered =
              Lottie.network(
                url,
                repeat:
                    config[
                      'repeat'
                    ] !=
                    false,
              );
        } else if (
          asset.isNotEmpty
        ) {
          rendered =
              Lottie.asset(
                asset,
                repeat:
                    config[
                      'repeat'
                    ] !=
                    false,
              );
        } else {
          rendered =
              const SizedBox.shrink();
        }

        break;


      case 'spacing.spacer':
        rendered =
            SizedBox(
              height:
                  _double(
                    config[
                      'height'
                    ],
                    16,
                  ),
            );

        break;


      case 'spacing.divider':
        rendered =
            const Divider();

        break;


      case 'stac.raw':
        final raw =
            config[
              'json'
            ];

        rendered =
            raw is Map
            ? (
                  Stac.fromJson(
                    Map<String, dynamic>.from(
                      raw,
                    ),
                    context,
                  ) ??
                  const SizedBox.shrink()
              )
            : const SizedBox.shrink();

        break;


      default:
        rendered =
            const SizedBox.shrink();
    }


    return _animate(
      rendered,
      block[
        'animation'
      ],
    );
  }


  List<Widget> _children(
    BuildContext context,
    List<String> ids,
    Map<String, Map<String, dynamic>>
    map, {
    required bool vertical,
    required double gap,
  }) {
    final result =
        <Widget>[];

    for (
      var index = 0;
      index < ids.length;
      index += 1
    ) {
      final block =
          map[
            ids[
              index
            ]
          ];

      if (
        block == null ||
        !runtime.isVisible(
          block[
            'visibility'
          ],
        )
      ) {
        continue;
      }

      final child =
          _renderBlock(
            context,
            block,
            map,
          );

      if (
        !vertical
      ) {
        result.add(
          Expanded(
            child:
                child,
          ),
        );
      } else {
        result.add(
          child,
        );
      }

      if (
        index !=
        ids.length - 1
      ) {
        result.add(
          vertical
              ? SizedBox(
                  height:
                      gap,
                )
              : SizedBox(
                  width:
                      gap,
                ),
        );
      }
    }

    return result;
  }


  Widget _textWidget(
    String text,
    Map<String, dynamic> config,
  ) {
    final size =
        config[
          'size'
        ]?.toString() ??
        'body';

    final fontSize =
        switch (
          size
        ) {
          'hero' => 64.0,
          'large' => 36.0,
          'title' => 28.0,
          'small' => 13.0,
          _ => 18.0,
        };

    final alignment =
        config[
          'alignment'
        ]?.toString();

    return SizedBox(
      width:
          double.infinity,

      child:
          Text(
            text,

            textAlign:
                alignment ==
                'center'
                ? TextAlign.center
                : alignment ==
                      'right'
                    ? TextAlign.right
                    : TextAlign.left,

            style:
                TextStyle(
                  fontSize:
                      fontSize,

                  fontWeight:
                      size ==
                              'hero' ||
                          size ==
                              'large' ||
                          size ==
                              'title'
                      ? FontWeight.w800
                      : FontWeight.w500,
                ),
          ),
    );
  }


  Widget _animate(
    Widget child,
    dynamic raw,
  ) {
    if (
      raw is! Map
    ) {
      return child;
    }

    final animation =
        Map<String, dynamic>.from(
          raw,
        );

    final preset =
        animation[
          'preset'
        ]?.toString() ??
        'none';

    final duration =
        Duration(
          milliseconds:
              (
                animation[
                      'durationMs'
                    ]
                    as num?
              )
                  ?.toInt() ??
              350,
        );

    switch (preset) {
      case 'fade':
        return Animate(
          effects: [
            FadeEffect(
              duration:
                  duration,
            ),
          ],
          child:
              child,
        );

      case 'scale':
        return Animate(
          effects: [
            ScaleEffect(
              begin:
                  const Offset(
                    0.88,
                    0.88,
                  ),
              end:
                  const Offset(
                    1,
                    1,
                  ),
              duration:
                  duration,
            ),
          ],
          child:
              child,
        );

      case 'fade_scale':
        return Animate(
          effects: [
            FadeEffect(
              duration:
                  duration,
            ),
            ScaleEffect(
              begin:
                  const Offset(
                    0.82,
                    0.82,
                  ),
              end:
                  const Offset(
                    1,
                    1,
                  ),
              duration:
                  duration,
            ),
          ],
          child:
              child,
        );

      case 'slide_up':
        return Animate(
          effects: [
            FadeEffect(
              duration:
                  duration,
            ),
            SlideEffect(
              begin:
                  const Offset(
                    0,
                    0.18,
                  ),
              end:
                  Offset.zero,
              duration:
                  duration,
            ),
          ],
          child:
              child,
        );

      case 'pulse':
        return Animate(
          effects: [
            ScaleEffect(
              begin:
                  const Offset(
                    0.92,
                    0.92,
                  ),
              end:
                  const Offset(
                    1.05,
                    1.05,
                  ),
              duration:
                  duration,
            ),
          ],
          child:
              child,
        );

      case 'shake':
        return Animate(
          effects: [
            ShakeEffect(
              duration:
                  duration,
            ),
          ],
          child:
              child,
        );

      default:
        return child;
    }
  }


  static CrossAxisAlignment
  _crossAxis(
    dynamic value,
  ) {
    switch (
      value?.toString()
    ) {
      case 'center':
        return CrossAxisAlignment.center;

      case 'end':
      case 'right':
        return CrossAxisAlignment.end;

      default:
        return CrossAxisAlignment.stretch;
    }
  }


  static double _double(
    dynamic value,
    double fallback,
  ) {
    if (
      value is num
    ) {
      return value
          .toDouble();
    }

    return double.tryParse(
          value?.toString() ??
              '',
        ) ??
        fallback;
  }


  static String _display(
    dynamic value,
  ) {
    if (
      value == null ||
      value == ''
    ) {
      return '0';
    }

    if (
      value is num
    ) {
      final number =
          value.toDouble();

      if (
        number ==
        number.roundToDouble()
      ) {
        return number
            .toInt()
            .toString();
      }

      return number
          .toStringAsFixed(
            2,
          );
    }

    return value.toString();
  }


  static Color? _hexColor(
    String? value,
  ) {
    if (
      value == null ||
      value.isEmpty
    ) {
      return null;
    }

    var hex =
        value.replaceAll(
          '#',
          '',
        );

    if (
      hex.length ==
      6
    ) {
      hex =
          'FF$hex';
    }

    final parsed =
        int.tryParse(
          hex,
          radix:
              16,
        );

    return parsed == null
        ? null
        : Color(
            parsed,
          );
  }
}
