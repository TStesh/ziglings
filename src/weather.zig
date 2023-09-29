const std = @import("std");
const http = std.http;
const heap = std.heap;
const uri = std.Uri;
const mem = std.mem;
const fmt = std.fmt;
const ascii = std.ascii;
const process = std.process;
const AutoHashMap = std.AutoHashMap;
const json = std.json;
const debug = std.debug;
const print = debug.print;

const Value = struct { 
	results: [1](struct {
		id: u32,
		name: []const u8,
		latitude: f32,
		longitude: f32,
		elevation: f32,
		feature_code: []const u8,
		country_code: []const u8,
        admin1_id: u32,
        timezone: []const u8,
        population: u32,
        country_id: u32,
        country: []const u8,
        admin1: []const u8,
	}),
	generationtime_ms: f32,
};

const Place = struct { 
	latitude: f32, 
	longitude: f32 
};

const Weather = struct {
	latitude: f32,
    longitude: f32,
    generationtime_ms: f32,
    utc_offset_seconds: u16,
    timezone: []const u8,
    timezone_abbreviation: []const u8,
    elevation: u16,
    daily_units: struct {
        time: []u8,
        weathercode: []u8,
        temperature_2m_max: []u8,
        temperature_2m_min: []u8,
        apparent_temperature_max: []u8,
        apparent_temperature_min: []u8,
        precipitation_hours: []u8,
        precipitation_probability_max: []u8,
        windspeed_10m_max: []u8,
        winddirection_10m_dominant: []u8,
    },
    daily: struct {
        time: [5][10]u8,
        weathercode: [5]u8,
        temperature_2m_max: [5]f32,
        temperature_2m_min: [5]f32,
        apparent_temperature_max: [5]f32,
        apparent_temperature_min: [5]f32,
        precipitation_hours: [5]u8,
        precipitation_probability_max: [5]u8,
        windspeed_10m_max: [5]f32,
        winddirection_10m_dominant: [5]u16,
    }
};

fn setWeatherCode(malloc: mem.Allocator) !AutoHashMap(u8, []const u8) {
	var wc = AutoHashMap(u8, []const u8).init(malloc);
	
	try wc.put(0, "Clear sky");									// Ясно
	try wc.put(1, "Mainly clear");								// Преимущественно ясно
	try wc.put(2, "Mainly partly cloudy");						// Облачно
	try wc.put(3, "Mainly overcast");							// Пасмурно
	try wc.put(45, "Fog");										// Туман
	try wc.put(48, "Depositing rime fog");						// Выпадение инея
	try wc.put(51, "Light intensity Drizzle");					// Слабая морось
	try wc.put(53, "Moderate intensity Drizzle");				// Средняя морось
	try wc.put(55, "Dense intensity Drizzle");					// Густая морось
	try wc.put(56, "Light intensity Freezing drizzle");			// Слабый ледяная дождь
	try wc.put(57, "Dense intensity Freezing drizzle");			// Плотный ледяной дождь
	try wc.put(61, "Slight intensity Rain");					// Дождливо
	try wc.put(63, "Moderate intensity Rain");					// Дождь 
	try wc.put(65, "Heavy intensity Rain");						// Ливень
	try wc.put(66, "Light intensity Freezing Rain");
	try wc.put(67, "Heavy intensity Freezing Rain");
	try wc.put(71, "Slight intensity Snow fall");
	try wc.put(73, "Moderate intensity Snow fall");
	try wc.put(75, "Heavy intensity Snow fall");
	try wc.put(77, "Snow grains");
	try wc.put(80, "Slight Rain showers");
	try wc.put(81, "Moderate Rain showers");
	try wc.put(82, "Violent Rain showers");
	try wc.put(85, "Slight Snow showers");
	try wc.put(86, "Heavy Snow showers");
	try wc.put(95, "Slight (or moderate) Thunderstorm");
	try wc.put(96, "Thunderstorm with slight hail");
	try wc.put(97, "Thunderstorm with heavy hail");
	
	return wc;
} 

fn concat(malloc: mem.Allocator, a: []u8, b: []u8) ![]u8 {
	var result = try malloc.alloc(u8, a.len + b.len);
    mem.copy(u8, result, a);
    mem.copy(u8, result[a.len..], b);
    return result;
}  

fn getLatLong(
	malloc: mem.Allocator, 
	city: []u8
) anyerror!Place {
	var path_pref = "https://geocoding-api.open-meteo.com/v1/search?name=".*;
	var path_suff = "&count=1&language=en&format=json".*;
	var path = try concat(malloc, &path_pref, city);
	path = try concat(malloc, path, &path_suff);

	print("Get the place json...", .{});
	
	var my_uri = try uri.parse(path);
	
    var client: http.Client = .{ .allocator = malloc };
    defer client.deinit();
	
    var req = try client.request(.GET, my_uri, .{ .allocator = malloc }, .{});
    defer req.deinit();
	
    try req.start();
    try req.wait();

    if (req.response.status == .ok) {
		var buf = try malloc.alloc(u8, 512);
		var bytes = try req.read(buf);
		print("OK (get bytes: {d})\n", .{bytes});
		print("Parse the place json...", .{});
		const loc = json.parseFromSlice(Value, malloc, buf[0..bytes], .{}) catch |err| {
			switch (err) {
				error.MissingField => 
					print("error: the city '{s}' was not found in the remote DB\n", .{city}),
				error.UnknownField => {
					print("error: the city '{s}' was found in the remote DB, ", .{city});
					print("but its json structure is different from default\n", .{});
				},
				else => {}
			}
			return err;
		};
		defer loc.deinit();
		
		var lat = loc.value.results[0].latitude;
		var lon = loc.value.results[0].longitude;
		
		print("OK (latitude: {d:.5}, longitude: {d:.5})\n", .{lat, lon});
	
		return Place { .latitude = lat, .longitude = lon };
	}
	
	print("status: {any}\n", .{req.response.status});
	print("reason: {any}\n", .{req.response.reason});
	
	return error.NoData;
} 


fn getWeather(
	malloc: mem.Allocator, 
	p: Place
) anyerror!Weather {
	var lat = try fmt.allocPrint(malloc, "{d:.5}", .{p.latitude});
	var lng = try fmt.allocPrint(malloc, "{d:.5}", .{p.longitude});
	var path_pref = "https://api.open-meteo.com/v1/forecast?latitude=".*;
	var path_x = "&longitude=".*;
	var path_suff = "&daily=weathercode,temperature_2m_max,temperature_2m_min,apparent_temperature_max,apparent_temperature_min,precipitation_hours,precipitation_probability_max,windspeed_10m_max,winddirection_10m_dominant&timezone=Europe%2FMoscow&forecast_days=5".*;
	var path = try concat(malloc, &path_pref, lat);
	path = try concat(malloc, path, &path_x);
	path = try concat(malloc, path, lng);
	path = try concat(malloc, path, &path_suff);
	
	print("Getting the weather json...", .{});
	
	var my_uri = try uri.parse(path);
	
    var client: http.Client = .{ .allocator = malloc };
    defer client.deinit();

    var req = try client.request(.GET, my_uri, .{ .allocator = malloc }, .{});
    defer req.deinit();
	
    try req.start();
    try req.wait();

    if (req.response.status == .ok) {
		var buf = try malloc.alloc(u8, 1512);
		var bytes = try req.read(buf);
		print("OK (get bytes: {d})\n", .{bytes});
		
		print("Parse the weather json...", .{});
		const loc = try json.parseFromSlice(Weather, malloc, buf[0..bytes], .{});
		defer loc.deinit();
		print("OK\n", .{});
		
		return loc.value;
	}
	
	print("status: {any}\n", .{req.response.status});
	print("reason: {any}\n", .{req.response.reason});
	
	return error.NoData;
}


fn parseDailyWeather(
	malloc: mem.Allocator, 
	w: *Weather
) !void {
	const wc = try setWeatherCode(malloc);
	
	print("\n\nWeather:\n", .{});
	
	//     2023-09-29:         Mainly overcast          | 23.4 | 10.6 | 22.6  |  9.8  |  0   |  0   |  7.4    | 252 ( S)
	print("-----------+---------------------------------+------+------+-------+-------+------+------+---------+---------\n", .{});
	print("Date       |      Weather description        | T,°C | T,°C | AT,°C | AT,°C | PH,h | PP,% | WS,km/h | WD,° (D)\n", .{});
	print("-----------+---------------------------------+------+------+-------+-------+------+------+---------+---------\n", .{});
	
	for(0..5) |i| {		
		print("{s} |", .{w.daily.time[i]});
		print("{s:^32} |", .{wc.get(w.daily.weathercode[i]).?});
		print("{d:>5.1} |", .{w.daily.temperature_2m_max[i]});
		print("{d:>5.1} |", .{w.daily.temperature_2m_min[i]});
		print("{d:>6.1} |", .{w.daily.apparent_temperature_max[i]});
		print("{d:>6.1} |", .{w.daily.apparent_temperature_min[i]});
		print("{d:>5.0} |", .{w.daily.precipitation_hours[i]});
		print("{d:>5.0} |", .{w.daily.precipitation_probability_max[i]});
		print("{d:>8.1} |", .{w.daily.windspeed_10m_max[i]});
		var wd = w.daily.winddirection_10m_dominant[i];
		print("{d:>4.0} (", .{wd});
		
		//   UV U UZ
		//    V   Z
		//   SV S SZ
		const wn = switch (wd) {
			31...60 => "UZ",
			61...120 => "U",
			121...150 => "UV",
			151...210 => "V",
			211...240 => "SV",
			241...300 => "S",
			301...330 => "SZ",
			else => "Z",
		};
		
		print("{s:>2})\n", .{wn});
	}
	print("-----------+---------------------------------+------+------+-------+-------+------+------+---------+---------\n", .{});
}

pub fn main() !void {
	// memory initialize
    var gpa_alloc = heap.GeneralPurposeAllocator(.{}) {};
    defer debug.assert(gpa_alloc.deinit() == .ok);
	const gpa = gpa_alloc.allocator();
	var arena_instance = heap.ArenaAllocator.init(gpa);
	defer arena_instance.deinit();
	const arena = arena_instance.allocator();
	
	const args = try process.argsAlloc(arena);
    defer process.argsFree(arena, args);
	
	var p = "moscow".*;
	var city = switch (args.len) {
		2 => args[1],
		else => blk: {
			print("\nUsage: weather [CITY]\n", .{});
			print("By default the CITY is the Moscow, RU\n\n", .{});
			break :blk &p;
		}
	};
	
	var cap_city = try ascii.allocUpperString(arena, city);
	print("\nProcessing the city '{s}':\n", .{cap_city});
	
	const loc = try getLatLong(arena, city);
	var weather = try getWeather(arena, loc);
	try parseDailyWeather(arena, &weather);
}