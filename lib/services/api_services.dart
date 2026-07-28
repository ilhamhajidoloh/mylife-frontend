import '../config/api_config.dart';
import 'api_client.dart';

class AuthApiService {
  static Future<dynamic> register(
    String email,
    String password,
    String fullName,
  ) async {
    return await ApiClient.post(ApiConfig.authRegister, {
      'email': email,
      'password': password,
      'fullName': fullName,
    });
  }

  static Future<dynamic> login(String email, String password) async {
    return await ApiClient.post(ApiConfig.authLogin, {
      'email': email,
      'password': password,
    });
  }

  static Future<dynamic> socialLogin(
    String provider,
    String providerId,
    String email,
    String fullName,
  ) async {
    return await ApiClient.post(ApiConfig.authSocialLogin, {
      'provider': provider,
      'providerId': providerId,
      'email': email,
      'fullName': fullName,
    });
  }
}

class FinanceApiService {
  static Future<dynamic> getTransactions(String userId) async {
    return await ApiClient.get(ApiConfig.finance(userId));
  }

  static Future<dynamic> getSummary(String userId) async {
    return await ApiClient.get(ApiConfig.financeSummary(userId));
  }

  static Future<dynamic> addTransaction(
    String userId,
    double amount,
    bool isIncome,
    String category,
    String title,
  ) async {
    return await ApiClient.post('${ApiConfig.baseUrl}/api/finance', {
      'userId': userId,
      'type': isIncome ? 0 : 1,
      'amount': amount,
      'category': category,
      'note': title,
      'transactionDate': DateTime.now().toIso8601String(),
    });
  }

  static Future<dynamic> updateTransaction(
    String id,
    String userId,
    double amount,
    bool isIncome,
    String category,
    String title, {
    DateTime? transactionDate,
  }) async {
    return await ApiClient.put('${ApiConfig.baseUrl}/api/finance/$id', {
      'id': id,
      'userId': userId,
      'type': isIncome ? 0 : 1,
      'amount': amount,
      'category': category,
      'note': title,
      'transactionDate': (transactionDate ?? DateTime.now()).toIso8601String(),
    });
  }

  static Future<dynamic> deleteTransaction(String id) async {
    return await ApiClient.delete('${ApiConfig.baseUrl}/api/finance/$id');
  }

  static Future<dynamic> getBreakdown(
    String userId,
    String period, {
    int? year,
    int? month,
  }) async {
    return await ApiClient.get(
      ApiConfig.financeBreakdown(userId, period, year: year, month: month),
    );
  }

  static Future<dynamic> getRecurring(String userId) async {
    return await ApiClient.get(ApiConfig.financeRecurring(userId));
  }

  static Future<dynamic> addRecurring(
    String userId,
    String title,
    double amount,
    String category,
    DateTime startDate,
    DateTime? endDate,
    bool isIndefinite,
    int dayOfMonthDue,
  ) async {
    return await ApiClient.post(ApiConfig.financeRecurring(userId), {
      'userId': userId,
      'title': title,
      'amount': amount,
      'category': category,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'isIndefinite': isIndefinite,
      'dayOfMonthDue': dayOfMonthDue,
    });
  }

  static Future<dynamic> updateRecurring(
    String id,
    String userId,
    String title,
    double amount,
    String category,
    DateTime startDate,
    DateTime? endDate,
    bool isIndefinite,
    int dayOfMonthDue,
  ) async {
    return await ApiClient.put(ApiConfig.financeRecurringItem(id), {
      'id': id,
      'userId': userId,
      'title': title,
      'amount': amount,
      'category': category,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'isIndefinite': isIndefinite,
      'dayOfMonthDue': dayOfMonthDue,
    });
  }

  static Future<dynamic> deleteRecurring(String id) async {
    return await ApiClient.delete(ApiConfig.financeRecurringItem(id));
  }
}

class ScheduleApiService {
  static Future<dynamic> getTerms(String userId) async {
    return await ApiClient.get(ApiConfig.scheduleTerms(userId));
  }

  static Future<dynamic> getTodayClasses(String userId) async {
    return await ApiClient.get(ApiConfig.scheduleTodayClasses(userId));
  }

  static Future<dynamic> addTerm(
    String userId,
    String termName,
    DateTime startDate,
    DateTime endDate,
  ) async {
    return await ApiClient.post('${ApiConfig.baseUrl}/api/schedule/terms', {
      'userId': userId,
      'termName': termName,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
    });
  }

  static Future<dynamic> updateTerm(
    String id,
    String userId,
    String termName,
    DateTime startDate,
    DateTime endDate,
  ) async {
    return await ApiClient.put('${ApiConfig.baseUrl}/api/schedule/terms/$id', {
      'id': id,
      'userId': userId,
      'termName': termName,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
    });
  }

  static Future<dynamic> addCourse(
    String termId,
    String code,
    String name,
    String room,
    String instructor,
    int dayOfWeek,
    String startTime,
    String endTime,
  ) async {
    final cSharpDay = dayOfWeek == 7 ? 0 : dayOfWeek;
    return await ApiClient.post('${ApiConfig.baseUrl}/api/schedule/courses', {
      'termId': termId,
      'courseCode': code,
      'courseName': name,
      'room': room,
      'instructor': instructor,
      'dayOfWeek': cSharpDay,
      'startTime': '$startTime:00',
      'endTime': '$endTime:00',
    });
  }

  static Future<dynamic> updateCourse(
    String courseId,
    String termId,
    String code,
    String name,
    String room,
    String instructor,
    int dayOfWeek,
    String startTime,
    String endTime,
  ) async {
    final cSharpDay = dayOfWeek == 7 ? 0 : dayOfWeek;
    return await ApiClient.put(
      '${ApiConfig.baseUrl}/api/schedule/courses/$courseId',
      {
        'id': courseId,
        'termId': termId,
        'courseCode': code,
        'courseName': name,
        'room': room,
        'instructor': instructor,
        'dayOfWeek': cSharpDay,
        'startTime': '$startTime:00',
        'endTime': '$endTime:00',
      },
    );
  }

  static Future<dynamic> deleteCourse(String courseId) async {
    return await ApiClient.delete(
      '${ApiConfig.baseUrl}/api/schedule/courses/$courseId',
    );
  }
}

class ActivityApiService {
  static Future<dynamic> getActivities(String userId) async {
    return await ApiClient.get(ApiConfig.activity(userId));
  }

  static Future<dynamic> getTimeline(String userId) async {
    return await ApiClient.get(ApiConfig.activityTimeline(userId));
  }

  static Future<dynamic> addActivity(
    String userId,
    String title,
    String description,
    String location,
    bool isAllDay,
    bool isMultiDay,
    bool isIndefinite,
    String recurrence, {
    DateTime? startTime,
    DateTime? endTime,
  }) async {
    int recurrenceValue = 0;
    switch (recurrence) {
      case 'ทุกวัน':
        recurrenceValue = 1;
        break;
      case 'ทุกสัปดาห์':
        recurrenceValue = 2;
        break;
      case 'ทุกเดือน':
        recurrenceValue = 3;
        break;
      case 'ทุกปี':
        recurrenceValue = 4;
        break;
    }
    return await ApiClient.post('${ApiConfig.baseUrl}/api/activity', {
      'userId': userId,
      'title': title,
      'description': description,
      'location': location,
      'isAllDay': isAllDay,
      'isMultiDay': isMultiDay,
      'isIndefinite': isIndefinite,
      'recurrence': recurrenceValue,
      'startTime': startTime?.toLocal().toIso8601String(),
      'endTime': endTime?.toLocal().toIso8601String(),
    });
  }

  static Future<dynamic> updateActivity(
    String activityId,
    String userId,
    String title,
    String description,
    String location,
    bool isAllDay,
    bool isMultiDay,
    bool isIndefinite,
    String recurrence, {
    DateTime? startTime,
    DateTime? endTime,
  }) async {
    int recurrenceValue = 0;
    switch (recurrence) {
      case 'ทุกวัน':
        recurrenceValue = 1;
        break;
      case 'ทุกสัปดาห์':
        recurrenceValue = 2;
        break;
      case 'ทุกเดือน':
        recurrenceValue = 3;
        break;
      case 'ทุกปี':
        recurrenceValue = 4;
        break;
    }
    return await ApiClient.put(
      '${ApiConfig.baseUrl}/api/activity/$activityId',
      {
        'userId': userId,
        'title': title,
        'description': description,
        'location': location,
        'isAllDay': isAllDay,
        'isMultiDay': isMultiDay,
        'isIndefinite': isIndefinite,
        'recurrence': recurrenceValue,
        'startTime': startTime?.toLocal().toIso8601String(),
        'endTime': endTime?.toLocal().toIso8601String(),
      },
    );
  }

  static Future<dynamic> deleteActivity(String activityId) async {
    return await ApiClient.delete(
      '${ApiConfig.baseUrl}/api/activity/$activityId',
    );
  }
}

class TodoApiService {
  static Future<dynamic> getTodos(
    String userId, {
    String? tag,
    int? year,
    int? month,
    int? day,
  }) async {
    final params = <String, String>{};
    if (tag != null && tag != 'ทั้งหมด') params['tag'] = tag;
    if (year != null) params['year'] = '$year';
    if (month != null) params['month'] = '$month';
    if (day != null) params['day'] = '$day';
    final query = params.isEmpty
        ? ''
        : '?${params.entries.map((e) => '${e.key}=${e.value}').join('&')}';
    return await ApiClient.get('${ApiConfig.todo(userId)}$query');
  }

  static Future<dynamic> getDailyCompletion(String userId) async {
    return await ApiClient.get(ApiConfig.todoDailyCompletion(userId));
  }

  static Future<dynamic> addTodo(
    String userId,
    String title,
    String tag,
    DateTime targetDate,
    int recurrence,
  ) async {
    return await ApiClient.post('${ApiConfig.baseUrl}/api/todo', {
      'userId': userId,
      'title': title,
      'tag': tag,
      'targetDate': targetDate.toIso8601String(),
      'recurrence': recurrence,
      'isCompleted': false,
    });
  }

  static Future<dynamic> updateTodo(
    String id,
    String title,
    String tag,
    DateTime targetDate,
    int recurrence,
    bool isCompleted,
  ) async {
    return await ApiClient.put('${ApiConfig.baseUrl}/api/todo/$id', {
      'id': id,
      'title': title,
      'tag': tag,
      'targetDate': targetDate.toIso8601String(),
      'recurrence': recurrence,
      'isCompleted': isCompleted,
    });
  }

  static Future<dynamic> deleteTodo(String id) async {
    return await ApiClient.delete('${ApiConfig.baseUrl}/api/todo/$id');
  }

  /// ติ๊กสำเร็จ/ยกเลิก — ใช้ endpoint นี้แทน updateTodo เพราะรองรับ todo แบบทำซ้ำ
  /// (แต่ละวันที่เกิดซ้ำมีสถานะสำเร็จแยกกัน ผ่านตาราง TodoCompletions)
  static Future<dynamic> updateCompletion(String id, bool isCompleted, DateTime date) async {
    return await ApiClient.put('${ApiConfig.baseUrl}/api/todo/$id/completion', {
      'isCompleted': isCompleted,
      'date': date.toIso8601String(),
    });
  }
}

class TaskApiService {
  static Future<dynamic> getTasks(String userId) async {
    return await ApiClient.get(ApiConfig.task(userId));
  }

  static Future<dynamic> getUrgentTasks(String userId) async {
    return await ApiClient.get(ApiConfig.taskUrgent(userId));
  }

  static Future<dynamic> addTask(
    String userId,
    String title,
    String subject,
    bool isUrgent,
    DateTime deadline,
  ) async {
    return await ApiClient.post('${ApiConfig.baseUrl}/api/task', {
      'userId': userId,
      'title': title,
      'subject': subject,
      'deadline': deadline.toIso8601String(),
      'isUrgent': isUrgent,
      'isCompleted': false,
    });
  }

  static Future<dynamic> updateTask(
    String id,
    String title,
    String subject,
    bool isUrgent,
    bool isCompleted,
    DateTime deadline,
  ) async {
    return await ApiClient.put('${ApiConfig.baseUrl}/api/task/$id', {
      'id': id,
      'title': title,
      'subject': subject,
      'isUrgent': isUrgent,
      'isCompleted': isCompleted,
      'deadline': deadline.toIso8601String(),
    });
  }

  static Future<dynamic> deleteTask(String id) async {
    return await ApiClient.delete('${ApiConfig.baseUrl}/api/task/$id');
  }
}

class HealthApiService {
  static Future<dynamic> logHealthData(
    String userId,
    int steps,
    int heartRate,
  ) async {
    return await ApiClient.post('${ApiConfig.baseUrl}/api/health', {
      'userId': userId,
      'stepCount': steps,
      'heartRate': heartRate,
      'recordedAt': DateTime.now().toIso8601String(),
    });
  }

  static Future<dynamic> getChartData(String userId) async {
    return await ApiClient.get(ApiConfig.healthChartData(userId));
  }
}
