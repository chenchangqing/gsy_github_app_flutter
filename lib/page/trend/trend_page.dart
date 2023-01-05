import 'dart:async';

import 'package:animations/animations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:gsy_github_app_flutter/common/localization/default_localizations.dart';
import 'package:gsy_github_app_flutter/common/style/gsy_style.dart';
import 'package:gsy_github_app_flutter/common/utils/navigator_utils.dart';
import 'package:gsy_github_app_flutter/model/TrendingRepoModel.dart';
import 'package:gsy_github_app_flutter/page/repos/repository_detail_page.dart';
import 'package:gsy_github_app_flutter/page/repos/widget/repos_item.dart';
import 'package:gsy_github_app_flutter/page/trend/trend_bloc.dart';
import 'package:gsy_github_app_flutter/page/trend/trend_user_page.dart';
import 'package:gsy_github_app_flutter/redux/gsy_state.dart';
import 'package:gsy_github_app_flutter/widget/gsy_card_item.dart';
import 'package:gsy_github_app_flutter/widget/pull/nested/gsy_sliver_header_delegate.dart';
import 'package:gsy_github_app_flutter/widget/pull/nested/nested_refresh.dart';
import 'package:redux/redux.dart';

/**
 * 主页趋势tab页
 * 目前采用纯 bloc 的 rxdart(stream) + streamBuilder
 * Created by guoshuyu
 * Date: 2018-07-16
 */
class TrendPage extends StatefulWidget {
  TrendPage({Key? super.key});

  @override
  TrendPageState createState() => TrendPageState();
}

class TrendPageState extends State<TrendPage>
    with
        AutomaticKeepAliveClientMixin<TrendPage>,

        /// 固定头部需要该类型的参数
        SingleTickerProviderStateMixin {
  ///显示数据时间
  TrendTypeModel? selectTime = null;
  int selectTimeIndex = 0;

  ///显示过滤语言
  TrendTypeModel? selectType = null;
  int selectTypeIndex = 0;

  /// NestedScrollView 的刷新状态 GlobalKey ，方便主动刷新使用
  final GlobalKey<NestedScrollViewRefreshIndicatorState> refreshIndicatorKey =
      new GlobalKey<NestedScrollViewRefreshIndicatorState>();

  ///滚动控制与监听
  final ScrollController scrollController = new ScrollController();

  ///bloc
  final TrendBloc trendBloc = new TrendBloc();

  ///显示刷新
  _showRefreshLoading() {
    new Future.delayed(const Duration(seconds: 0), () {
      refreshIndicatorKey.currentState!.show().then((e) {});
      return true;
    });
  }

  /// 双击Tab置顶或置顶刷新
  scrollToTop() {
    if (scrollController.offset <= 0) {
      scrollController
          .animateTo(0,
              duration: Duration(milliseconds: 600), curve: Curves.linear)
          .then((_) {
        _showRefreshLoading();
      });
    } else {
      scrollController.animateTo(0,
          duration: Duration(milliseconds: 600), curve: Curves.linear);
    }
  }

  ///绘制tiem
  _renderItem(e) {
    ReposViewModel reposViewModel = ReposViewModel.fromTrendMap(e);

    /// OpenContainer：打开页面的过渡动画
    /// https://blog.csdn.net/zl18603543572/article/details/107830140
    return OpenContainer(
      closedColor: Colors.transparent,
      closedElevation: 0,
      transitionType: ContainerTransitionType.fade,
      openBuilder: (BuildContext context, VoidCallback _) {
        return NavigatorUtils.pageContainer(
            RepositoryDetailPage(
                reposViewModel.ownerName, reposViewModel.repositoryName),
            context);
      },
      tappable: true,
      closedBuilder: (BuildContext _, VoidCallback openContainer) {
        return new ReposItem(reposViewModel, onPressed: null);
      },
    );
  }

  ///绘制头部可选item
  _renderHeader(Store<GSYState> store, Radius radius) {
    if (selectTime == null && selectType == null) {
      return Container();
    }
    var trendTimeList = trendTime(context);
    var trendTypeList = trendType(context);
    return new GSYCardItem(
      color: store.state.themeData!.primaryColor,
      margin: EdgeInsets.all(0.0),
      shape: new RoundedRectangleBorder(
        borderRadius: BorderRadius.all(radius), //radius: 通过参数传入
      ),
      child: new Padding(
        padding:
            new EdgeInsets.only(left: 0.0, top: 5.0, right: 0.0, bottom: 5.0),
        child: new Row(
          children: <Widget>[
            /// 渲染周期
            _renderHeaderPopItem(selectTime!.name, trendTimeList,
                (TrendTypeModel result) {
              /// 选中项目后的操作
              /// 当正在请求的时候，如果点击选择项目，
              /// 此次选择不生效，并且给出提示信息
              if (trendBloc.isLoading) {
                /// 提示封装
                Fluttertoast.showToast(
                    msg: GSYLocalizations.i18n(context)!.loading_text);
                return;
              }

              /// 选择完事件后，列表置顶，设置选择值
              scrollController
                  .animateTo(0,
                      duration: Duration(milliseconds: 200),
                      curve: Curves.bounceInOut)
                  .then((_) {
                setState(() {
                  selectTime = result;
                  selectTimeIndex = trendTimeList.indexOf(result);
                });

                /// 触发下拉刷新
                _showRefreshLoading();
              });
            }),

            /// 分割线
            new Container(height: 10.0, width: 0.5, color: GSYColors.white),

            /// 渲染语言
            _renderHeaderPopItem(selectType!.name, trendTypeList,
                (TrendTypeModel result) {
              if (trendBloc.isLoading) {
                Fluttertoast.showToast(
                    msg: GSYLocalizations.i18n(context)!.loading_text);
                return;
              }
              scrollController
                  .animateTo(0,
                      duration: Duration(milliseconds: 200),
                      curve: Curves.bounceInOut)
                  .then((_) {
                setState(() {
                  selectType = result;
                  selectTypeIndex = trendTypeList.indexOf(result);
                });
                _showRefreshLoading();
              });
            }),
          ],
        ),
      ),
    );
  }

  ///或者头部可选弹出item容器
  _renderHeaderPopItem(String data, List<TrendTypeModel> list,
      PopupMenuItemSelected<TrendTypeModel> onSelected) {
    return new Expanded(
      /// 选项按钮
      child: new PopupMenuButton<TrendTypeModel>(
        child: new Center(
            child: new Text(data, style: GSYConstant.middleTextWhite)),
        onSelected: onSelected,
        itemBuilder: (BuildContext context) {
          return _renderHeaderPopItemChild(list);
        },
      ),
    );
  }

  ///或者头部可选弹出item
  _renderHeaderPopItemChild(List<TrendTypeModel> data) {
    /// 构建选项列表
    List<PopupMenuEntry<TrendTypeModel>> list = [];
    for (TrendTypeModel item in data) {
      list.add(PopupMenuItem<TrendTypeModel>(
        value: item,
        child: new Text(item.name),
      ));
    }
    return list;
  }

  /// 刷新请求
  Future<void> requestRefresh() async {
    return trendBloc.requestRefresh(selectTime, selectType);
  }

  /// 页面保活
  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    if (!trendBloc.requested) {
      /// 如果没有请求过，选择项默认第一个
      setState(() {
        selectTime = trendTime(context)[0];
        selectType = trendType(context)[0];
      });

      /// 显示下拉刷新，发起请求
      _showRefreshLoading();
    } else {
      /// 发起redux请求时，会再次进入`didChangeDependencies`
      /// 如果请求完成，重新绘制
      /// 下面这两个if其实没啥用，因为选择项目后，就会设置selectTime、selectType
      if (selectTimeIndex >= 0) {
        selectTime = trendTime(context)[selectTimeIndex];
      }
      if (selectTypeIndex >= 0) {
        selectType = trendType(context)[selectTypeIndex];
      }
      setState(() {});
    }
    super.didChangeDependencies();
  }

  ///空页面
  Widget _buildEmpty() {
    /// 获取状态栏高度（顶部安全距离）
    var statusBar =
        MediaQueryData.fromWindow(WidgetsBinding.instance.window).padding.top;

    /// 获取底部安全距离
    var bottomArea = MediaQueryData.fromWindow(WidgetsBinding.instance.window)
        .padding
        .bottom;
    var height = MediaQuery.of(context).size.height -
        statusBar -
        bottomArea -
        kBottomNavigationBarHeight -

        /// BottomNavigationBar 高度
        kToolbarHeight;

    /// AppBar 高度
    return SingleChildScrollView(
      child: new Container(
        height: height,
        width: MediaQuery.of(context).size.width,
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // See AutomaticKeepAliveClientMixin.
    return new StoreBuilder<GSYState>(
      builder: (context, store) {
        return new Scaffold(
          backgroundColor: GSYColors.mainBackgroundColor,

          ///采用目前采用纯 bloc 的 rxdart(stream) + streamBuilder
          body: StreamBuilder<List<TrendingRepoModel>?>(
              stream: trendBloc.stream,
              builder: (context, snapShot) {
                ///下拉刷新
                return new NestedScrollViewRefreshIndicator(
                  key: refreshIndicatorKey,

                  ///嵌套滚动
                  child: NestedScrollView(
                    controller: scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    headerSliverBuilder: (context, innerBoxIsScrolled) {
                      /// 头部构建
                      return _sliverBuilder(context, innerBoxIsScrolled, store);
                    },
                    body: (snapShot.data == null || snapShot.data!.length == 0)
                        ? _buildEmpty()/// 空页面构建
                        : new ListView.builder(/// 列表构建
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemBuilder: (context, index) {
                              return _renderItem(snapShot.data![index]);
                            },
                            itemCount: snapShot.data!.length,
                          ),
                  ),
                  onRefresh: requestRefresh,
                );
              }),
          floatingActionButton: trendUserButton(),
        );
      },
    );
  }

  trendUserButton() {
    final double size = 56.0;
    return OpenContainer(
      transitionType: ContainerTransitionType.fade,
      openBuilder: (BuildContext context, VoidCallback _) {
        return NavigatorUtils.pageContainer(new TrendUserPage(), context);
      },
      /// 按钮阴影
      closedElevation: 6.0,
      /// 按钮形状
      closedShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(
          Radius.circular(size / 2),
        ),
      ),
      /// 按钮背景色
      closedColor: Theme.of(context).colorScheme.secondary,
      closedBuilder: (BuildContext context, VoidCallback openContainer) {
        return SizedBox(
          width: size,
          height: size,
          child: Icon(
            Icons.person,
            size: 30,
            color: Colors.white,
          ),
        );
      },
    );
  }

  ///嵌套可滚动头部
  List<Widget> _sliverBuilder(
      BuildContext context, bool innerBoxIsScrolled, Store store) {
    return <Widget>[
      ///动态头部
      SliverPersistentHeader(
        pinned: true,

        ///SliverPersistentHeaderDelegate 实现
        delegate: GSYSliverHeaderDelegate(
            maxHeight: 65,
            minHeight: 65,
            changeSize: true,
            /// 一个 [TickerProvider] 在动画标题的大小变化时使用。
            /// https://www.jianshu.com/p/0205c3c78a25
            vSyncs: this,
            /// 指定浮动标题在视图内外的动画效果。
            snapConfig: FloatingHeaderSnapConfiguration(
              curve: Curves.bounceInOut,
              duration: const Duration(milliseconds: 10),
            ),
            builder: (BuildContext context, double shrinkOffset,
                bool overlapsContent) {
              if (kDebugMode) {
                print('shrink: $shrinkOffset，overlaps:$overlapsContent');
              }
              /// 根据数值计算偏差
              /// 刚好到顶时shrinkOffset为0，继续往上shrinkOffset值增加
              /// 根据上移的偏移量设置上、左、右的边距，还有圆角
              var lr = 10 - shrinkOffset / 65 * 10;
              var radius = Radius.circular(4 - shrinkOffset / 65 * 4);
              return SizedBox.expand(
                child: Padding(
                  padding:
                      EdgeInsets.only(top: lr, bottom: 15, left: lr, right: lr),
                  child: _renderHeader(store as Store<GSYState>, radius),
                ),
              );
            }),
      ),
    ];
  }
}

///趋势数据过滤显示item
class TrendTypeModel {
  final String name;
  final String? value;

  TrendTypeModel(this.name, this.value);
}

///趋势数据时间过滤
List<TrendTypeModel> trendTime(BuildContext context) {
  return [
    new TrendTypeModel(GSYLocalizations.i18n(context)!.trend_day, "daily"),
    new TrendTypeModel(GSYLocalizations.i18n(context)!.trend_week, "weekly"),
    new TrendTypeModel(GSYLocalizations.i18n(context)!.trend_month, "monthly"),
  ];
}

///趋势数据语言过滤
List<TrendTypeModel> trendType(BuildContext context) {
  return [
    TrendTypeModel(GSYLocalizations.i18n(context)!.trend_all, null),
    TrendTypeModel("Java", "Java"),
    TrendTypeModel("Kotlin", "Kotlin"),
    TrendTypeModel("Dart", "Dart"),
    TrendTypeModel("Objective-C", "Objective-C"),
    TrendTypeModel("Swift", "Swift"),
    TrendTypeModel("JavaScript", "JavaScript"),
    TrendTypeModel("PHP", "PHP"),
    TrendTypeModel("Go", "Go"),
    TrendTypeModel("C++", "C++"),
    TrendTypeModel("C", "C"),
    TrendTypeModel("HTML", "HTML"),
    TrendTypeModel("CSS", "CSS"),
    TrendTypeModel("Python", "Python"),
    TrendTypeModel("C#", "c%23"),
  ];
}
