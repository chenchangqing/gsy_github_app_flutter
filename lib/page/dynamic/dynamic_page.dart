import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:gsy_github_app_flutter/page/dynamic/dynamic_bloc.dart';
import 'package:gsy_github_app_flutter/common/dao/repos_dao.dart';
import 'package:gsy_github_app_flutter/model/Event.dart';
import 'package:gsy_github_app_flutter/redux/gsy_state.dart';
import 'package:gsy_github_app_flutter/common/utils/event_utils.dart';
import 'package:gsy_github_app_flutter/widget/gsy_event_item.dart';
import 'package:gsy_github_app_flutter/widget/pull/gsy_pull_new_load_widget.dart';
import 'package:redux/redux.dart';

/**
 * 主页动态tab页
 * Created by guoshuyu
 * Date: 2018-07-16
 */
class DynamicPage extends StatefulWidget {
  final bool userIos;
  DynamicPage({Key? super.key, this.userIos = false});

  @override
  DynamicPageState createState() => DynamicPageState();
}

/// AutomaticKeepAliveClientMixin：保持页面状态
/// WidgetsBindingObserver：监测页面生命周期
/// https://www.jianshu.com/p/2fd5562c1c9b
class DynamicPageState extends State<DynamicPage>
    with AutomaticKeepAliveClientMixin<DynamicPage>, WidgetsBindingObserver {
  final DynamicBloc dynamicBloc = new DynamicBloc();

  /// 控制列表滚动和监听
  final ScrollController scrollController = new ScrollController();

  final GlobalKey<RefreshIndicatorState> refreshIndicatorKey =
      new GlobalKey<RefreshIndicatorState>();

  /// true：列表不可以点击，false：下拉刷新请求完毕后，列表可以点击
  bool _ignoring = false;

  /// 模拟IOS下拉显示刷新
  showRefreshLoading() {
    /// 直接触发下拉
    /// 141：140可以触发下拉刷新，所以这里设置141
    new Future.delayed(const Duration(milliseconds: 500), () {
      if (widget.userIos) {
        scrollController
            .animateTo(-141,
            duration: Duration(milliseconds: 600), curve: Curves.linear)
            .then((_) {
          /*setState(() {
            _ignoring = false;
          });*/
        });
      } else {
        refreshIndicatorKey.currentState?.show();
      }
      return true;
    });
  }

  scrollToTop() {
    if (scrollController.offset <= 0) {
      /// 回到顶部，然后再触发下拉刷新
      scrollController
          .animateTo(0,
              duration: Duration(milliseconds: 600), curve: Curves.linear)
          .then((_) {
        showRefreshLoading();
      });
    } else {
      /// 仅回到顶部
      scrollController.animateTo(0,
          duration: Duration(milliseconds: 600), curve: Curves.linear);
    }
  }

  ///下拉刷新数据
  Future<void> requestRefresh() async {
    await dynamicBloc
        .requestRefresh(_getStore().state.userInfo?.login)
        .catchError((e) {
      print(e);
    });
    /// 下拉刷新后，更新_ignoring = false，进行重新绘制
    /// 使列表可以接收事件，例如下拉滑动事件、点击动态Item事件
    setState(() {
      _ignoring = false;
    });
  }

  ///上拉更多请求数据
  Future<void> requestLoadMore() async {
    return await dynamicBloc.requestLoadMore(_getStore().state.userInfo?.login);
  }

  _renderEventItem(Event e) {
    EventViewModel eventViewModel = EventViewModel.fromEventMap(e);
    return new GSYEventItem(
      eventViewModel,
      onPressed: () {
        EventUtils.ActionUtils(context, e, "");
      },
    );
  }

  Store<GSYState> _getStore() {
    return StoreProvider.of(context);
  }

  @override
  void initState() {
    super.initState();

    ///监听生命周期，主要判断页面 resumed 的时候触发刷新
    WidgetsBinding.instance.addObserver(this);

    ///获取网络端新版信息
    ReposDao.getNewsVersion(context, false);
  }

  @override
  void didChangeDependencies() {
    ///请求更新
    if (dynamicBloc.getDataLength() == 0) {
      /// 因为动态列表没有头部，所以直接写死
      dynamicBloc.changeNeedHeaderStatus(false);

      ///先读数据库
      dynamicBloc
          .requestRefresh(_getStore().state.userInfo?.login, doNextFlag: false)
          .then((_) {
            /// 触发一次下拉刷新，发起网络请求
        showRefreshLoading();
      });
    }
    super.didChangeDependencies();
  }

  ///监听生命周期，主要判断页面 resumed 的时候触发刷新
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (dynamicBloc.getDataLength() != 0) {
        showRefreshLoading();
      }
    }
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    dynamicBloc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // AutomaticKeepAlive详解
    // https://juejin.cn/post/6979972557575782407
    super.build(context); // See AutomaticKeepAliveClientMixin.
    var content = GSYPullLoadWidget(
      dynamicBloc.pullLoadWidgetControl,
      (BuildContext context, int index) =>
          _renderEventItem(dynamicBloc.dataList[index]),
      requestRefresh,
      requestLoadMore,
      refreshKey: refreshIndicatorKey,
      scrollController: scrollController,

      ///使用ios模式的下拉刷新
      userIos: widget.userIos,
    );
    // 刷新的时候列表不可以点击
    // https://blog.csdn.net/mengks1987/article/details/105440465
    // https://www.jianshu.com/p/6df5f0cea0bc
    return IgnorePointer(
      ignoring: _ignoring,
      child: content,
    );
  }
}
