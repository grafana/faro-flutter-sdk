import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:developer';

import '../rum_flutter.dart';

Element? _clickTrackerElement;
const _tapAreaSizeSquared = 20 * 20.0;


class UserInteractionProperties{
  Element? element;
  String? elementType;
  String? description;
  String? eventType;
  UserInteractionProperties({this.element,this.elementType,this.description,this.eventType}) {
}
}

class RumUserInteractionWidget extends StatefulWidget {
  final Widget child;
  const RumUserInteractionWidget({Key? key, required this.child}) : super(key: key);

  @override
  StatefulElement createElement() {
    final element = super.createElement();
    _clickTrackerElement = element;
   return element;
  }

  @override
  _RumUserInteractionWidgetState createState() =>
      _RumUserInteractionWidgetState();
}

class _RumUserInteractionWidgetState extends State<RumUserInteractionWidget> {
  int? _lastPointerId;
  Offset? _lastPointerDownLocation;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      onPointerUp: _onPointerUp,
      child: widget.child,
    );
  }

  void _onPointerDown(PointerDownEvent event) {
    _lastPointerId = event.pointer;
    _lastPointerDownLocation = event.localPosition;
  }

  void _onPointerUp(PointerUpEvent event) {
    if (_lastPointerDownLocation != null && event.pointer == _lastPointerId) {
      final distanceOffset = Offset(
          _lastPointerDownLocation!.dx - event.localPosition.dx,
          _lastPointerDownLocation!.dy - event.localPosition.dy);

      final distanceSquared = distanceOffset.distanceSquared;
      if (distanceSquared < _tapAreaSizeSquared) {
        _onTapped(event.localPosition, "tap");
      }
    }
  }

  void _onTapped(Offset localPosition, String tap) {
    final tappedElement = _findElementTapped(localPosition);
    if(tappedElement !=null) {
      RumFlutter().pushEvent('user_interaction', attributes: {
        "element_type": tappedElement.elementType,
        "element_description": tappedElement.description,
        "event_type": tappedElement.eventType,
        "event": "onClick"
      });
    }
  }

  UserInteractionProperties? _findElementTapped(Offset position) {
    final rootElement = _clickTrackerElement;
    if (rootElement == null || rootElement.widget != widget) {
      return null;
    }
    UserInteractionProperties? tappedWidget;
    void elementFind(Element element) {
      if (tappedWidget != null) {
        return;
      }
      final renderObject = element.renderObject;
      if (renderObject == null) {
        return null;
      }
      var hitFound = true;
      final hitTest = BoxHitTestResult();
      if (renderObject is RenderPointerListener) {
        final widgetName = element?.widget.toString();
        final widgetKey = element?.widget.key.toString();
        hitFound = renderObject.hitTest(hitTest, position: position);
      }
      final transform = renderObject.getTransformTo(rootElement.renderObject);
      final paintBounds =
      MatrixUtils.transformRect(transform, renderObject.paintBounds);

      if (!paintBounds.contains(position)) {
        return;
      }

      tappedWidget = _getWidgetfromElement(element);

      if (tappedWidget == null || !hitFound) {
        tappedWidget = null;
        element.visitChildElements(elementFind);
      }
    }
    rootElement.visitChildElements(elementFind);
    return tappedWidget;
  }

  String _getElementDescription(Element element, {bool allowText = true}) {
    String description = "";
    // traverse tree to find a suiting element
    void descriptionFinder(Element element) {
      bool foundDescription = false;

      final widget = element.widget;
      if (allowText && widget is Text) {
        final data = widget.data;
        if (data != null && data.isNotEmpty) {
          description = data;
          foundDescription = true;
        }
      } else if (widget is Semantics) {
        if (widget.properties.label?.isNotEmpty ?? false) {
          description = widget.properties.label!;
          foundDescription = true;
        }
      } else if (widget is Icon) {
        if (widget.semanticLabel?.isNotEmpty ?? false) {
          description = widget.semanticLabel!;
          foundDescription = true;
        }
      }

      if (!foundDescription) {
        element.visitChildren(descriptionFinder);
      }
    }
    descriptionFinder(element);
    return description;
  }

  UserInteractionProperties? _getWidgetfromElement(Element element) {
    final  widget = element.widget;
    if (widget is ButtonStyleButton) {
      if (widget.enabled) {
        return UserInteractionProperties(
            element: element,
            elementType: "ButtonStyleButton",
            description: _getElementDescription(element),
            eventType: "onClick"
        );
      }
    }
    else if (widget is MaterialButton) {
        if (widget.enabled) {
          return UserInteractionProperties(
              element: element,
              elementType: "MaterialButton",
              description: _getElementDescription(element),
              eventType: "onClick"
          );
        }
      } else if (widget is CupertinoButton) {
        if (widget.enabled) {
          return UserInteractionProperties(
              element: element,
              elementType: "CupertinoButton",
              description: _getElementDescription(element),
              eventType: "onPressed"
          );
        }
      } else if (widget is PopupMenuButton) {
        if (widget.enabled) {
          return UserInteractionProperties(
              element: element,
              elementType: "PopupMenuButton",
              description: _getElementDescription(element),
              eventType: "onTap"
          );
        }
      } else if (widget is PopupMenuItem) {
        if (widget.enabled) {
          return UserInteractionProperties(
              element: element,
              elementType: "PopupMenuItem",
              description: _getElementDescription(element),
              eventType: "onTap"
          );
        }
      } else if (widget is InkWell) {
        if (widget.onTap != null) {
          return UserInteractionProperties(
              element: element,
              elementType: "InkWell",
              description: _getElementDescription(element),
              eventType: "onTap"
          );
        }
      } else if (widget is IconButton) {
        if (widget.onPressed != null) {
          return UserInteractionProperties(
              element: element,
              elementType: "IconButton",
              description: _getElementDescription(element),
              eventType: "onPressed"
          );
        }
      }
      return null;
    }
  }