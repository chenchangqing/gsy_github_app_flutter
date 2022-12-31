import 'package:flare_flutter/flare_actor.dart';
import 'package:gsy_github_app_flutter/common/localization/default_localizations.dart';
import 'package:gsy_github_app_flutter/widget/pull/gsy_refresh_sliver.dart'
    as IOS;
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:gsy_github_app_flutter/common/style/gsy_style.dart';

import 'custom_bouncing_scroll_physics.dart';
import 'gsy_flare_pull_controller.dart';

const double iosRefreshHeight = 140;
const double iosRefreshIndicatorExtent = 100;

///通用下上刷新控件
class GSYPullLoadWidget extends StatefulWidget {
  /// item渲染
  /// 动态Item的绘制
  final IndexedWidgetBuilder itemBuilder;

  /// 加载更多回调
  /// 通过暴露该回调函数，可以将上拉加载的网络请求放在页面层
  /// 等待请求完毕会直接更新control数据控制层，
  /// 然后通过监听数据变化，调用setState，使页面重绘
  final RefreshCallback? onLoadMore;

  /// 下拉刷新回调
  /// 同onLoadMore，页面层请求数据后更新数据，通知页面重新绘制
  final RefreshCallback? onRefresh;

  /// 控制器，比如数据和一些配置
  /// 管理页面数据，例如：动态列表、是否需要显示更多、是否正在加载数据等
  /// 注意：needHeader这个属性目前是写死了为false，因为这个列表没有头部UI
  final GSYPullLoadWidgetControl control;

  /// 页面层传入，主要是为了让页面层控制列表的滑动
  /// 例如：页面层使列表回到顶部、触发下拉刷新等操作
  final ScrollController? scrollController;

  /// 是否使用iOS的下拉刷新
  /// 注意：如果此参数传false，依然无法触发android下拉刷新
  /// 因为页面层通过设置_ignore为true，使得列表不响应下拉事件
  /// 所以还需要将_ignore设置为false
  final bool userIos;

  /// 刷新key，android下拉刷新使用
  /// 注意：因为目前项目使用的是iOS的下拉刷新，暂时没地方使用
  /// 默认情况我们都是通过下拉触发刷新
  final Key? refreshKey;

  GSYPullLoadWidget(
      this.control, this.itemBuilder, this.onRefresh, this.onLoadMore,
      {this.refreshKey, this.scrollController, this.userIos = false});

  @override
  _GSYPullLoadWidgetState createState() => _GSYPullLoadWidgetState();
}

class _GSYPullLoadWidgetState extends State<GSYPullLoadWidget>
    /// GSYFlarePullController：构建下拉刷新动画使用
    /// 使用了flare_flutter包实现
    /// https://pub.dev/packages/flare_flutter
    with GSYFlarePullController {
  //with GSYFlarePullMutliController {

  final GlobalKey<IOS.CupertinoSliverRefreshControlState> sliverRefreshKey =
      GlobalKey<IOS.CupertinoSliverRefreshControlState>();
  /// 控制iOS下拉和动态列表的sliver滑动
  ScrollController? _scrollController;

  /// 刷新动作前设置true，刷新动作完毕设置为false
  /// 控制是否调用onRefresh（页面刷新请求）
  bool isRefreshing = false;

  /// 同isRefreshing
  bool isLoadMoring = false;

  /// GSYFlarePullController属性覆盖
  /// flare_flutter包需要
  @override
  ValueNotifier<bool> isActive = ValueNotifier<bool>(true);

  @override
  void initState() {
    /// 持有页面层传递过来的scrollController
    _scrollController = widget.scrollController ?? new ScrollController();

    /// 增加滑动监听
    _scrollController!.addListener(() {
      /// 判断当前滑动位置是不是到达底部，触发加载更多回调
      /// maxScrollExtent：
      /// 此值通常应为非空值且大于或等于 minScrollExtent。 如果卷轴是无界的，它可以是无穷大。
      /// 上拉的最大偏移量，手动上拉时候会超过这个值，松开就回弹
      /// pixels:
      /// 当前列表的偏移量，下拉是负值，上拉是正值
      /// 上拉请求触发条件
      /// print(_scrollController!.position.pixels);
      if (_scrollController!.position.pixels ==
          _scrollController!.position.maxScrollExtent) {
        if (widget.control.needLoadMore) {
          handleLoadMore();
        }
      }
    });
    /// 监听了上拉加载，数据请求完毕，调用setState进行重绘
    /// 注释掉，上拉加载动画会一直在，因为不会重绘
    widget.control.addListener(() {
      setState(() {});
      /// 暂时不知道有啥用！！！
      try {
        Future.delayed(Duration(seconds: 2), () {
          // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
          _scrollController!.notifyListeners();
        });
      } catch (e) {
        print(e);
      }
    });
    super.initState();
  }

  ///根据配置状态返回实际列表数量
  ///实际上这里可以根据你的需要做更多的处理
  ///比如多个头部，是否需要空页面，是否需要显示加载更多。
  _getListCount() {
    ///是否需要头部
    if (widget.control.needHeader) {
      ///如果需要头部，用Item 0 的 Widget 作为ListView的头部
      ///列表数量大于0时，因为头部和底部加载更多选项，需要对列表数据总数+2
      return (widget.control.dataList!.length > 0)
          ? widget.control.dataList!.length + 2
          : widget.control.dataList!.length + 1;
    } else {
      ///如果不需要头部，在没有数据时，固定返回数量1用于空页面呈现
      if (widget.control.dataList!.length == 0) {
        return 1;
      }

      ///如果有数据,因为部加载更多选项，需要对列表数据总数+1
      return (widget.control.dataList!.length > 0)
          ? widget.control.dataList!.length + 1
          : widget.control.dataList!.length;
    }
  }

  ///根据配置状态返回实际列表渲染Item
  _getItem(int index) {
    if (!widget.control.needHeader &&
        index == widget.control.dataList!.length &&
        widget.control.dataList!.length != 0) {
      ///如果不需要头部，并且数据不为0，当index等于数据长度时，渲染加载更多Item（因为index是从0开始）
      return _buildProgressIndicator();
    } else if (widget.control.needHeader &&
        index == _getListCount() - 1 &&
        widget.control.dataList!.length != 0) {
      ///如果需要头部，并且数据不为0，当index等于实际渲染长度 - 1时，渲染加载更多Item（因为index是从0开始）
      return _buildProgressIndicator();
    } else if (!widget.control.needHeader &&
        widget.control.dataList!.length == 0) {
      ///如果不需要头部，并且数据为0，渲染空页面
      return _buildEmpty();
    } else {
      ///回调外部正常渲染Item，如果这里有需要，可以直接返回相对位置的index
      return widget.itemBuilder(context, index);
    }
  }

  /// 每秒判断下是否在loading，如果在就继续等待
  _lockToAwait() async {
    ///if loading, lock to await
    doDelayed() async {
      await Future.delayed(Duration(seconds: 1)).then((_) async {
        if (widget.control.isLoading) {
          return await doDelayed();
        } else {
          return null;
        }
      });
    }

    await doDelayed();
  }

  @protected
  Future<Null> handleRefresh() async {
    /// isLoading：是否在刷新请求或加载更多请求
    /// 如果是刷新请求，那么返回；
    /// 反之，那就是加载更多请求，这时候等待加载更多完成
    if (widget.control.isLoading) {
      if (isRefreshing) {
        return null;
      }

      ///if loading, lock to await
      await _lockToAwait();
    }
    widget.control.isLoading = true;
    isRefreshing = true;
    /// 调用页面的刷新请求
    await widget.onRefresh?.call();
    isRefreshing = false;
    widget.control.isLoading = false;
    return null;
  }

  @protected
  Future<Null> handleLoadMore() async {
    /// 同上刷新等待
    if (widget.control.isLoading) {
      if (isLoadMoring) {
        return null;
      }

      ///if loading, lock to await
      await _lockToAwait();
    }
    isLoadMoring = true;
    widget.control.isLoading = true;
    /// 调用页面的加载更多请求
    await widget.onLoadMore?.call();
    isLoadMoring = false;
    widget.control.isLoading = false;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.userIos) {
      ///用ios模式的下拉刷新
      return new NotificationListener(
        onNotification: (ScrollNotification notification) {
          ///通知 CupertinoSliverRefreshControl 当前的拖拽状态
          sliverRefreshKey.currentState!.notifyScrollNotification(notification);
          return false;
        },
        child: CustomScrollView(
          controller: _scrollController,

          ///回弹效果
          physics: const CustomBouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
              refreshHeight: iosRefreshHeight),
          slivers: <Widget>[
            ///控制显示刷新的 CupertinoSliverRefreshControl
            IOS.CupertinoSliverRefreshControl(
              key: sliverRefreshKey,
              refreshIndicatorExtent: iosRefreshIndicatorExtent,
              refreshTriggerPullDistance: iosRefreshHeight,
              onRefresh: handleRefresh,
              builder: buildSimpleRefreshIndicator,
            ),
            SliverSafeArea(
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (BuildContext context, int index) {
                    return _getItem(index);
                  },
                  childCount: _getListCount(),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return new RefreshIndicator(
      ///GlobalKey，用户外部获取RefreshIndicator的State，做显示刷新
      key: widget.refreshKey,

      ///下拉刷新触发，返回的是一个Future
      onRefresh: handleRefresh,
      child: new ListView.builder(
        ///保持ListView任何情况都能滚动，解决在RefreshIndicator的兼容问题。
        physics: const AlwaysScrollableScrollPhysics(),

        ///根据状态返回子孔健
        itemBuilder: (context, index) {
          return _getItem(index);
        },

        ///根据状态返回数量
        itemCount: _getListCount(),

        ///滑动监听
        controller: _scrollController,
      ),
    );
  }

  ///空页面
  Widget _buildEmpty() {
    return new Container(
      height: MediaQuery.of(context).size.height - 100,
      child: new Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          TextButton(
            onPressed: () {},
            child: new Image(
                image: new AssetImage(GSYICons.DEFAULT_USER_ICON),
                width: 70.0,
                height: 70.0),
          ),
          Container(
            child: Text(GSYLocalizations.i18n(context)!.app_empty,
                style: GSYConstant.normalText),
          ),
        ],
      ),
    );
  }

  ///上拉加载更多
  Widget _buildProgressIndicator() {
    ///是否需要显示上拉加载更多的loading
    Widget bottomWidget = (widget.control.needLoadMore)
        ? new Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
                ///loading框
                new SpinKitRotatingCircle(
                    color: Theme.of(context).primaryColor),
                new Container(
                  width: 5.0,
                ),

                ///加载中文本
                new Text(
                  GSYLocalizations.i18n(context)!.load_more_text,
                  style: TextStyle(
                    color: Color(0xFF121917),
                    fontSize: 14.0,
                    fontWeight: FontWeight.bold,
                  ),
                )
              ])

        /// 不需要加载
        : new Container();
    return new Padding(
      padding: const EdgeInsets.all(20.0),
      child: new Center(
        child: bottomWidget,
      ),
    );
  }

  bool playAuto = false;

  @override
  bool get getPlayAuto => playAuto;

  @override
  double get refreshTriggerPullDistance => iosRefreshHeight;

  Widget buildSimpleRefreshIndicator(
    BuildContext? context,
    IOS.RefreshIndicatorMode? refreshState,
    double? pulledExtent,
    double? refreshTriggerPullDistance,
    double? refreshIndicatorExtent,
  ) {
    pulledExtentFlare = pulledExtent! * 0.6;
    playAuto = refreshState == IOS.RefreshIndicatorMode.refresh;
    /*if(refreshState == IOS.RefreshIndicatorMode.refresh) {
      onRefreshing();
    } else {
      onRefreshEnd();
    }*/
    return Align(
      alignment: Alignment.bottomCenter,
      child: new Container(
        color: Colors.black,
        width: MediaQuery.of(context!).size.width,

        ///动态大小处理
        height:
            pulledExtent > iosRefreshHeight ? pulledExtent : iosRefreshHeight,
        child: FlareActor(
            //"static/file/Space-Demo.flr",
            "static/file/loading_world_now.flr",
            alignment: Alignment.topCenter,
            fit: BoxFit.cover,
            controller: this,
            animation: "Earth Moving"
            //animation: "idle"
            ),
      ),
    );
  }
}

class GSYPullLoadWidgetControl extends ChangeNotifier {
  ///数据，对齐增减，不能替换
  List? _dataList = [];

  List? get dataList => _dataList;

 set dataList(List? value) {
    _dataList!.clear();
    if (value != null) {
      _dataList!.addAll(value);
      notifyListeners();
    }
  }

  addList(List? value) {
    if (value != null) {
      _dataList!.addAll(value);
      notifyListeners();
    }
  }

  ///是否需要加载更多
  bool _needLoadMore = true;

  set needLoadMore(value) {
    _needLoadMore = value;
    notifyListeners();
  }

  get needLoadMore => _needLoadMore;

  ///是否需要头部
  bool _needHeader = true;

  set needHeader(value) {
    _needHeader = value;
    notifyListeners();
  }

  get needHeader => _needHeader;

  ///是否加载中
  bool isLoading = false;
}
