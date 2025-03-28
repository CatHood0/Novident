import 'package:meta/meta.dart';
import 'package:novident_remake/src/domain/changes/node_change.dart';
import 'package:novident_remake/src/domain/entities/node/node.dart';
import 'package:novident_remake/src/domain/entities/tree_node/root_node.dart';
import 'package:novident_remake/src/domain/interfaces/nodes/node_visitor.dart';
import 'package:novident_remake/src/utils/typedefs.dart';

@internal
abstract class NodeContainer extends Node {
  final List<Node> _children;
  NodeNotifierChangeCallback? _notifierCallback;

  NodeContainer({
    required List<Node> children,
    required super.details,
  }) : _children = children;

  void onChange(NodeChange change) {
    _notifierCallback?.call(change);
  }

  void attachNotifier(NodeNotifierChangeCallback callback) {
    if (_notifierCallback == callback) return;
    _notifierCallback = callback;
    for (final Node child in children) {
      if (child is NodeContainer) {
        child.attachNotifier(callback);
      }
    }
  }

  void detachNotifier(NodeNotifierChangeCallback? callback) {
    if (_notifierCallback == null) return;
    if (_notifierCallback == callback) _notifierCallback = null;
    for (final Node child in children) {
      if (child is NodeContainer) {
        child.detachNotifier(callback);
      }
    }
  }

  /// Get all the nodes that satifies the predicate
  Iterable<Node> where(ConditionalPredicate<Node> predicate) {
    final List<Node> nodes = <Node>[];
    for (final Node node in children) {
      if (predicate(node)) {
        nodes.add(node);
      }
    }
    return nodes;
  }

  /// Get all the nodes that satifies the predicate traversing
  /// into every node that is NodeContainer and gettings its children
  Iterable<Node> whereDeep(ConditionalPredicate<Node> predicate) {
    final List<Node> nodes = <Node>[];
    for (final Node node in children) {
      if (predicate(node)) {
        nodes.add(node);
      } else if (node is NodeContainer) {
        nodes.addAll(node.whereDeep(predicate));
      }
    }
    return nodes;
  }

  @override
  Node? visitAllNodes(
      {required Predicate shouldGetNode, bool reversed = false}) {
    for (int i = reversed ? length - 1 : 0;
        reversed ? i >= 0 : i < length;
        reversed ? i-- : i++) {
      final Node node = elementAt(i);
      if (shouldGetNode(node)) {
        return node;
      }
      final Node? foundedNode =
          node.visitAllNodes(shouldGetNode: shouldGetNode);
      if (foundedNode != null) return foundedNode;
    }
    return null;
  }

  @override
  Node? visitNode({required Predicate shouldGetNode, bool reversed = false}) {
    for (int i = reversed ? length - 1 : 0;
        reversed ? i >= 0 : i < length;
        reversed ? i-- : i++) {
      final Node node = elementAt(i);
      if (shouldGetNode(node)) {
        return node;
      }
    }
    return null;
  }

  @override
  int countAllNodes({required Predicate countNode}) {
    int count = 0;
    for (int i = 0; i < length; i++) {
      final Node node = elementAt(i);
      if (countNode(node)) {
        count++;
      }
      count += node.countAllNodes(countNode: countNode);
    }
    return count;
  }

  @override
  int countNodes({required Predicate countNode}) {
    int count = 0;
    for (int i = 0; i < length; i++) {
      final Node node = elementAt(i);
      if (countNode(node)) {
        count++;
      }
    }
    return count;
  }

  /// Check if the id of the node exist in the root
  /// of the [Folder] without checking into its children
  @override
  bool exist(String nodeId) {
    for (int i = 0; i < length; i++) {
      if (elementAt(i).details.id == nodeId) return true;
    }
    return false;
  }

  /// Check if the id of the node exist into the [Folder]
  /// checking in its children without limitations
  ///
  /// This opertion could be heavy based on the deep of the nodes
  /// into the [Folder]
  @override
  bool deepExist(String nodeId) {
    for (int i = 0; i < length; i++) {
      final node = elementAt(i);
      if (node.details.id == nodeId) {
        return true;
      }
      final foundedNode = node.deepExist(nodeId);
      if (foundedNode) return true;
    }
    return false;
  }

  List<Node> get children => _children;

  Node get first => _children.first;

  Node get last => _children.last;

  Node? get lastOrNull => _children.lastOrNull;

  Node? get firstOrNull => _children.firstOrNull;

  Iterator<Node> get iterator => _children.iterator;

  Iterable<Node> get reversed => _children.reversed;

  bool get isEmpty => _children.isEmpty;

  bool get hasNoChildren => _children.isEmpty;

  bool get isNotEmpty => !isEmpty;

  int get length => _children.length;

  Node elementAt(int index) {
    return _children.elementAt(index);
  }

  Node? elementAtOrNull(int index) {
    return _children.elementAtOrNull(index);
  }

  bool contains(Object object) {
    return _children.contains(object);
  }

  void clearAndOverrideState(List<Node> newChildren) {
    clear();
    addAll(newChildren);
  }

  int indexWhere(bool Function(Node) callback) {
    return _children.indexWhere(callback);
  }

  int indexOf(Node element, int start) {
    return _children.indexOf(element, start);
  }

  Node firstWhere(bool Function(Node) callback) {
    return _children.firstWhere(callback);
  }

  Node lastWhere(bool Function(Node) callback) {
    return _children.lastWhere(callback);
  }

  NodeChange _decideInsertionOrMove({
    required Node to,
    required Node? from,
    required Node newState,
    required Node? oldState,
  }) {
    if (from == null) {
      return NodeInsertion(to: to, from: from, newState: newState);
    }
    return NodeMoveChange(to: to, from: from, newState: newState);
  }

  void add(Node element, {bool shouldNotify = true}) {
    onChange(
      _decideInsertionOrMove(
        to: this,
        from: element.owner,
        newState: element.clone()..owner = this,
        oldState: element,
      ),
    );
    if (element.owner != this) {
      element.owner = this;
    }
    _children.add(element);
    if (shouldNotify) notify();
  }

  void addAll(Iterable<Node> children, {bool shouldNotify = true}) {
    for (final Node child in children) {
      onChange(
        _decideInsertionOrMove(
          to: this,
          from: child.owner,
          newState: child.clone()..owner = this,
          oldState: child,
        ),
      );
      if (child.owner != this) {
        child.owner = this;
      }
      _children.add(child);
    }
    if (shouldNotify) notify();
  }

  void insert(int index, Node element, {bool shouldNotify = true}) {
    final Node originalElement = element.clone();
    if (element.owner != this) {
      element.owner = this;
    }
    _children.insert(index, element);
    onChange(
      _decideInsertionOrMove(
        to: this,
        from: originalElement.owner,
        newState: element.clone(),
        oldState: originalElement,
      ),
    );
    if (shouldNotify) notify();
  }

  void clear({bool shouldNotify = true}) {
    _children.clear();
    if (shouldNotify) notify();
  }

  bool remove(Node element, {bool shouldNotify = true}) {
    final int index = _children.indexOf(element);
    if (index <= -1) return false;
    _children.removeAt(index);
    onChange(
      NodeDeletion(
        originalPosition: index,
        sourceOwner:
            jumpToParent(stopAt: (Node node) => node is! Root && node.atRoot)!,
        inNode: clone(),
        newState: element,
        oldState: element,
      ),
    );
    if (shouldNotify) notify();
    return true;
  }

  @override
  NodeContainer clone();

  Node removeLast({bool shouldNotify = true}) {
    final Node value = _children.removeLast();
    onChange(
      NodeDeletion(
        originalPosition: _children.length,
        sourceOwner:
            jumpToParent(stopAt: (Node node) => node is! Root && node.atRoot)!,
        inNode: clone(),
        newState: value.clone(),
        oldState: value.clone(),
      ),
    );
    if (shouldNotify) notify();
    return value;
  }

  void removeWhere(bool Function(Node) callback, {bool shouldNotify = true}) {
    _children.removeWhere(callback);
    if (shouldNotify) notify();
  }

  Node removeAt(int index, {bool shouldNotify = true}) {
    final Node value = _children.removeAt(index);
    onChange(
      NodeDeletion(
        originalPosition: index,
        sourceOwner:
            jumpToParent(stopAt: (Node node) => node is! Root && node.atRoot)!,
        inNode: clone(),
        newState: value.clone(),
        oldState: value.clone(),
      ),
    );
    if (shouldNotify) notify();
    return value;
  }

  void operator []=(int index, Node newNodeState) {
    if (index < 0) return;
    onChange(
      NodeUpdate(
        newState: newNodeState,
        oldState: children[index],
      ),
    );
    if (newNodeState.owner != this) {
      newNodeState.owner = this;
    }
    _children[index] = newNodeState;
    notify();
  }

  Node operator [](int index) {
    return _children[index];
  }

  @override
  void dispose() {
    detachNotifier(_notifierCallback);
    super.dispose();
  }
}
