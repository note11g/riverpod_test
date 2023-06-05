import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: const HomePage(),
    );
  }
}

@immutable
class WeatherModel {
  const WeatherModel({required this.weatherState, required this.date});

  final String weatherState;
  final DateTime date;

  factory WeatherModel.fromJson(Map<String, dynamic> json) {
    return WeatherModel(
      weatherState: json['w_state'] as String,
      date: DateTime.fromMillisecondsSinceEpoch(json['date_ms']),
    );
  }

  Map<String, dynamic> toJson() => {
        'w_state': weatherState,
        'date_ms': date.millisecondsSinceEpoch,
      };

  @override
  String toString() {
    return 'WeatherModel{weatherState: $weatherState, date: $date}';
  }
}

class WeatherDAO {
  Future<WeatherModel> getNowWeather() async {
    final now = DateTime.now();
    await _simulateNetworkDelay();
    return WeatherModel(weatherState: _getRandomWeatherStatus(), date: now);
  }

  Future<WeatherModel> getWeatherForecast({required DateTime date}) async {
    await _simulateNetworkDelay();
    return WeatherModel(
      weatherState: _getRandomWeatherStatus(seed: date.millisecondsSinceEpoch),
      date: date,
    );
  }

  String _getRandomWeatherStatus({int? seed}) {
    final statusList = ["맑음", "흐림", "비"];
    final randomIndex = Random(seed).nextInt(statusList.length);
    return statusList[randomIndex];
  }

  Future<void> _simulateNetworkDelay({int ms = 500}) async {
    await Future.delayed(Duration(milliseconds: ms));
  }
}

class AsyncWeatherNotifier extends AsyncNotifier<List<WeatherModel>> {
  final WeatherDAO _weatherDAO;

  AsyncWeatherNotifier(this._weatherDAO);

  @override
  Future<List<WeatherModel>> build() async {
    final nowWeather = await _weatherDAO.getNowWeather();
    return [nowWeather];
  }

  Future<void> loadMoreForecast({int day = 3}) async {
    await _fetchDataOnUi(loadFunc: () async {
      final requestDateList = _getWillLoadForecastDateList(day: day);
      final forecastRequestList = requestDateList
          .map((date) => _weatherDAO.getWeatherForecast(date: date));

      final forecastResult = await Future.wait(forecastRequestList);
      return _combineOldDataAndNewData(newData: forecastResult);
    });
  }

  List<WeatherModel> _combineOldDataAndNewData<T>(
      {required List<WeatherModel> newData}) {
    final oldData = state.value ?? <WeatherModel>[];
    return [...oldData, ...newData];
  }

  DateTime get _lastLoadedDate => state.value?.last.date ?? DateTime.now();

  Future<void> _fetchDataOnUi({
    required Future<List<WeatherModel>> Function() loadFunc,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(loadFunc);
  }

  List<DateTime> _getWillLoadForecastDateList({required int day}) {
    final List<DateTime> reqDate = [];
    for (int i = 1; i <= day; i++) {
      reqDate.add(_lastLoadedDate.add(Duration(days: i)));
    }
    return reqDate;
  }
}

final asyncWeatherProvider =
    AsyncNotifierProvider<AsyncWeatherNotifier, List<WeatherModel>>(
        () => AsyncWeatherNotifier(WeatherDAO()));

class HomePage extends ConsumerWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncWeather = ref.watch(asyncWeatherProvider);

    return Scaffold(
        body: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
          Expanded(
            child: asyncWeather.when(
              data: (data) => ListView.builder(
                itemCount: data.length,
                itemBuilder: (context, index) => _weatherCard(data[index]),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Center(
                child: Text(
                  error.toString(),
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ),
          ),
          Padding(
              padding: const EdgeInsets.all(24),
              child: ElevatedButton(
                onPressed: () {
                  ref.read(asyncWeatherProvider.notifier).loadMoreForecast();
                },
                child: const Text('예보 3일 추가 로드'),
              )),
        ]));
  }

  Widget _weatherCard(WeatherModel weather) {
    final localizedDate = "${weather.date.month}월 ${weather.date.day}일";

    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Text(localizedDate),
            Text(weather.weatherState),
          ],
        ),
      ),
    );
  }
}
