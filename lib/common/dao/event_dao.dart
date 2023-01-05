import 'dart:convert';

import 'package:gsy_github_app_flutter/db/provider/event/received_event_db_provider.dart';
import 'package:gsy_github_app_flutter/db/provider/event/user_event_db_provider.dart';
import 'package:gsy_github_app_flutter/common/dao/dao_result.dart';
import 'package:gsy_github_app_flutter/model/Event.dart';
import 'package:gsy_github_app_flutter/common/net/address.dart';
import 'package:gsy_github_app_flutter/common/net/api.dart';

class EventDao {
  /// 刷新：加载本地数据，触发网络请求
  /// 加载更多：直接发起网络请求
  /// 注意：只缓存第一页数据，首次进入的时候会优先使用本地数据，
  /// 然后触发刷新网络请求，更新本地数据，同时刷新列表
  static getEventReceived(String? userName,
      {page = 1, bool needDb = false}) async {
    /// userName：用于拼接API地址
    if (userName == null) {
      return null;
    }
    /// 动态表查询/更新管理
    ReceivedEventDbProvider provider = new ReceivedEventDbProvider();
    /// 网络数据加载
    /// 本地没有数据时调用、本地数据加载完后，在通过next函数调用
    next() async {
      String url =
          Address.getEventReceived(userName) + Address.getPageParams("?", page);

      var res = await httpManager.netFetch(url, null, null, null);
      if (res != null && res.result) {
        List<Event> list = [];
        var data = res.data;
        if (data == null || data.length == 0) {
          return null;
        }
        if (needDb) {
          /// 更新本地数据
          await provider.insert(json.encode(data));
        }
        for (int i = 0; i < data.length; i++) {
          list.add(Event.fromJson(data[i]));
        }
        return new DataResult(list, true);
      } else {
        return new DataResult(null, false);
      }
    }

    if (needDb) {
      List<Event>? dbList = await provider.getEvents();
      if (dbList == null || dbList.length == 0) {
        return await next();
      }
      DataResult dataResult = new DataResult(dbList, true, next: next);
      return dataResult;
    }
    return await next();
  }

  /**
   * 用户行为事件
   */
  static getEventDao(userName, {page = 0, bool needDb = false}) async {
    UserEventDbProvider provider = new UserEventDbProvider();
    next() async {
      String url =
          Address.getEvent(userName) + Address.getPageParams("?", page);
      var res = await httpManager.netFetch(url, null, null, null);
      if (res != null && res.result) {
        List<Event> list = [];
        var data = res.data;
        if (data == null || data.length == 0) {
          return new DataResult(list, true);
        }
        if (needDb) {
          provider.insert(userName, json.encode(data));
        }
        for (int i = 0; i < data.length; i++) {
          list.add(Event.fromJson(data[i]));
        }
        return new DataResult(list, true);
      } else {
        return null;
      }
    }

    if (needDb) {
      List<Event>? dbList = await provider.getEvents(userName);
      if (dbList == null || dbList.length == 0) {
        return await next();
      }
      DataResult dataResult = new DataResult(dbList, true, next: next);
      return dataResult;
    }
    return await next();
  }
}
