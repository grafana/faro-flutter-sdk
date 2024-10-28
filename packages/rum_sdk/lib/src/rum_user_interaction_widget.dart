import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:rum_sdk/rum_flutter.dart';

Element? _clickTrackerElement;
const _tapAreaSizeSquared = 20 * 20.0;

class UserInteractionProperties {
  UserInteractionProperties(
      {this.element, this.elementType, this.description, this.eventType});
  Element? element;
  String? elementType;
  String? description;
  String? eventType;
}

class RumUserInteractionWidget extends StatefulWidget {
  const RumUserInteractionWidget({super.key, required this.child});
  final Widget child;

  @override
  StatefulElement createElement() {
    final element = super.createElement();
    _clickTrackerElement = element;
    return element;
  }

  @override
  State<RumUserInteractionWidget> createState() =>
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
        _onTapped(event.localPosition, 'tap');
      }
    }
  }

  void _onTapped(Offset localPosition, String tap) {
    final tappedElement = _findElementTapped(localPosition);
    if (tappedElement != null) {
      RumFlutter().pushEvent('user_interaction', attributes: {
        'element_type': tappedElement.elementType,
        'element_description': tappedElement.description,
        'event_type': tappedElement.eventType,
        'event': 'onClick'
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
        return;
      }
      var hitFound = true;
      final hitTest = BoxHitTestResult();
      if (renderObject is RenderPointerListener) {
        // These are not used currently, but they were in the code.
        // Do we want to use these? Let's think about it.
        // ignore: unused_local_variable
        final widgetName = element.widget.toString();
        // ignore: unused_local_variable
        final widgetKey = element.widget.key.toString();

        hitFound = renderObject.hitTest(hitTest, position: position);
      }
      final transform = renderObject.getTransformTo(rootElement.renderObject);
      final paintBounds =
          MatrixUtils.transformRect(transform, renderObject.paintBounds);

      if (!paintBounds.contains(position)) {
        return;
      }

      tappedWidget = _getWidgetFromElement(element);

      if (tappedWidget == null || !hitFound) {
        tappedWidget = null;
        element.visitChildElements(elementFind);
      }
    }

    rootElement.visitChildElements(elementFind);
    return tappedWidget;
  }

  String _getElementDescription(Element element, {bool allowText = true}) {
    var description = '';
    // traverse tree to find a suiting element
    void descriptionFinder(Element element) {
      var foundDescription = false;

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

  UserInteractionProperties? _getWidgetFromElement(Element element) {
    final widget = element.widget;
    if (widget is ButtonStyleButton) {
      if (widget.enabled) {
        return UserInteractionProperties(
            element: element,
            elementType: 'ButtonStyleButton',
            description: _getElementDescription(element),
            eventType: 'onClick');
      }
    } else if (widget is MaterialButton) {
      if (widget.enabled) {
        return UserInteractionProperties(
            element: element,
            elementType: 'MaterialButton',
            description: _getElementDescription(element),
            eventType: 'onClick');
      }
    } else if (widget is CupertinoButton) {
      if (widget.enabled) {
        return UserInteractionProperties(
            element: element,
            elementType: 'CupertinoButton',
            description: _getElementDescription(element),
            eventType: 'onPressed');
      }
    } else if (widget is PopupMenuButton) {
      if (widget.enabled) {
        return UserInteractionProperties(
            element: element,
            elementType: 'PopupMenuButton',
            description: _getElementDescription(element),
            eventType: 'onTap');
      }
    } else if (widget is PopupMenuItem) {
      if (widget.enabled) {
        return UserInteractionProperties(
            element: element,
            elementType: 'PopupMenuItem',
            description: _getElementDescription(element),
            eventType: 'onTap');
      }
    } else if (widget is InkWell) {
      if (widget.onTap != null) {
        return UserInteractionProperties(
            element: element,
            elementType: 'InkWell',
            description: _getElementDescription(element),
            eventType: 'onTap');
      }
    } else if (widget is IconButton) {
      if (widget.onPressed != null) {
        return UserInteractionProperties(
            element: element,
            elementType: 'IconButton',
            description: _getElementDescription(element),
            eventType: 'onPressed');
      }
    }
    return null;
  }
}
