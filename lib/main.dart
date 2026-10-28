import 'package:flutter/material.dart';

import 'bus.dart';
import 'storage.dart';
import 'weather.dart';

void main() {
  runApp(const BusBookingApp());
}

class BusBookingApp extends StatelessWidget {
  const BusBookingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo),
      home: const HomeScreen(),
    );
  }
}

// ---------------- Small helpers ----------------

IconData iconFor(int code) {
  if (code == 0) return Icons.wb_sunny;
  if (code <= 3) return Icons.cloud;
  if (code == 45 || code == 48) return Icons.foggy;
  if (code >= 95) return Icons.thunderstorm;
  if (code >= 51) return Icons.water_drop;
  return Icons.help_outline;
}

Color colorFor(int status) {
  if (status == 0) return Colors.grey;
  if (status == 1) return Colors.orange;
  return Colors.green;
}

City cityByName(String name) {
  for (final c in cities) {
    if (c.name == name) return c;
  }
  return cities[0];
}

// =====================================================================
// SCREEN 1: all the buses, filtered by From / To
// =====================================================================

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Bus> buses = [];
  bool ready = false;
  String fromFilter = 'Any';
  String toFilter = 'Any';

  @override
  void initState() {
    super.initState();
    start();
  }

  Future<void> start() async {
    final saved = await loadBuses();
    setState(() {
      buses = saved ?? sampleBuses(); // first time: sample data
      ready = true;
    });
  }

  // Saves every bus, with all its passengers.
  void save() {
    saveBuses(buses);
  }

  bool matches(Bus bus) {
    return (fromFilter == 'Any' || bus.from == fromFilter) &&
        (toFilter == 'Any' || bus.to == toFilter);
  }

  // Edit: move the bus to its next status.
  void advance(Bus bus) {
    final index = buses.indexOf(bus);
    setState(() {
      buses[index] = bus.next();
    });
    save();
  }

  // Delete, with Undo.
  void deleteBus(Bus bus) {
    final index = buses.indexOf(bus);
    setState(() {
      buses.removeAt(index);
    });
    save();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${bus.plate} deleted'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            setState(() {
              final position = index <= buses.length ? index : buses.length;
              buses.insert(position, bus);
            });
            save(); // undo is saved too
          },
        ),
      ),
    );
  }

  // Add a new bus between two of the four towns.
  Future<void> addBus() async {
    final plateController = TextEditingController();
    final timeController = TextEditingController(text: '08:00');
    var from = cities[0].name;
    var to = cities[1].name;

    final added = await showDialog<Bus>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('New bus'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: plateController,
                    decoration: const InputDecoration(labelText: 'Plate (e.g. RAC 123 B)'),
                  ),
                  TextField(
                    controller: timeController,
                    decoration: const InputDecoration(labelText: 'Departure (HH:MM)'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const SizedBox(width: 48, child: Text('From')),
                      Expanded(
                        child: cityDropdown(from, false,
                                (v) => setDialogState(() => from = v)),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const SizedBox(width: 48, child: Text('To')),
                      Expanded(
                        child: cityDropdown(to, false,
                                (v) => setDialogState(() => to = v)),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final plate = plateController.text.trim();
                    if (plate.isEmpty || from == to) return; // not valid
                    Navigator.pop(context,
                        Bus(plate, from, to, timeController.text.trim(), 0, [], []));
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );

    if (added == null) return;
    setState(() {
      buses.add(added);
    });
    save();
  }

  // Open the seat map of one bus. When we come back, redraw (seat counts changed).
  Future<void> openBus(Bus bus) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => BusScreen(bus: bus, onChanged: save)),
    );
    setState(() {});
  }

  // A dropdown of the four towns, with 'Any' first when withAny is true.
  Widget cityDropdown(String value, bool withAny, void Function(String) onChanged) {
    return DropdownButton<String>(
      value: value,
      isExpanded: true,
      items: [
        if (withAny) const DropdownMenuItem(value: 'Any', child: Text('Any')),
        for (final c in cities) DropdownMenuItem(value: c.name, child: Text(c.name)),
      ],
      onChanged: (v) => onChanged(v!),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = buses.where(matches).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Bus Booking')),
      floatingActionButton: FloatingActionButton(
        onPressed: addBus,
        tooltip: 'Add bus',
        child: const Icon(Icons.add),
      ),
      body: !ready
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                const Text('From  '),
                Expanded(
                  child: cityDropdown(fromFilter, true,
                          (v) => setState(() => fromFilter = v)),
                ),
                const SizedBox(width: 16),
                const Text('To  '),
                Expanded(
                  child: cityDropdown(toFilter, true,
                          (v) => setState(() => toFilter = v)),
                ),
              ],
            ),
          ),
          Expanded(
            child: visible.isEmpty
                ? const Center(child: Text('No bus on this route. Tap + to add one.'))
                : ListView(
              children: [for (final bus in visible) buildBusTile(bus)],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildBusTile(Bus bus) {
    final seats = bus.freeSeats == 0
        ? 'Full · ${bus.waitlist.length} waiting'
        : '${bus.freeSeats} seats free';
    return Dismissible(
      key: ObjectKey(bus),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => deleteBus(bus),
      child: ListTile(
        leading: Icon(Icons.directions_bus, color: colorFor(bus.status), size: 32),
        title: Text('${bus.from} → ${bus.to}   ${bus.departure}'),
        subtitle: Text('${bus.plate} · ${bus.statusLabel} · $seats'),
        onTap: () => openBus(bus),
        trailing: IconButton(
          icon: const Icon(Icons.skip_next),
          tooltip: 'Next status',
          onPressed: () => advance(bus),
        ),
      ),
    );
  }
}

// =====================================================================
// SCREEN 2: one bus — weather at the destination, seat map, waitlist
// =====================================================================

class BusScreen extends StatefulWidget {
  const BusScreen({super.key, required this.bus, required this.onChanged});

  final Bus bus;
  final VoidCallback onChanged; // tells the home screen to save

  @override
  State<BusScreen> createState() => _BusScreenState();
}

class _BusScreenState extends State<BusScreen> {
  // Undo: a copy of this bus's lists from before the last change
  List<Booking>? undoBookings;
  List<Passenger>? undoWaitlist;

  // Live weather at the destination (API): three states
  late City destination;
  Weather? weather;
  bool loadingWeather = true;
  String? weatherError;

  Bus get bus => widget.bus;

  @override
  void initState() {
    super.initState();
    destination = cityByName(bus.to);
    loadWeather();
  }

  // ---------------- API ----------------

  Future<void> loadWeather() async {
    try {
      final result = await fetchWeather(destination);
      if (!mounted) return; // the user already left this screen
      setState(() {
        weather = result;
        loadingWeather = false;
        weatherError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loadingWeather = false;
        weatherError = 'Could not load the weather. Check your internet connection.';
      });
    }
  }

  void retryWeather() {
    setState(() {
      loadingWeather = true;
      weatherError = null;
    });
    loadWeather();
  }

  // ---------------- Saving and undo ----------------

  // Call BEFORE every change. List.of makes a copy that later changes don't touch.
  void remember() {
    undoBookings = List.of(bus.bookings);
    undoWaitlist = List.of(bus.waitlist);
  }

  void undo() {
    if (undoBookings == null) return;
    setState(() {
      bus.bookings
        ..clear()
        ..addAll(undoBookings!);
      bus.waitlist
        ..clear()
        ..addAll(undoWaitlist!);
      undoBookings = null;
      undoWaitlist = null;
    });
    widget.onChanged(); // undo is saved too
    showMessage('Last change undone');
  }

  void showMessage(String text) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  // Booking is only allowed while the bus is still waiting.
  bool checkOpen() {
    if (bus.open) return true;
    showMessage('Booking is closed: this bus is ${bus.statusLabel.toLowerCase()}');
    return false;
  }

  // ---------------- Changes ----------------

  // Asks for a name and the priority mark. Null if Cancel is pressed.
  Future<Passenger?> askPassenger(String title) {
    final nameController = TextEditingController();
    var priority = false;
    return showDialog<Passenger>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(title),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'Passenger name'),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Priority (elderly, pregnant, disability)'),
                    value: priority,
                    onChanged: (v) => setDialogState(() => priority = v!),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    if (name.isEmpty) return; // a name is required
                    Navigator.pop(context, Passenger(name, priority));
                  },
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Tap a free seat: book exactly that seat.
  Future<void> bookSeat(int seat) async {
    if (!checkOpen()) return;
    final p = await askPassenger('Book seat $seat');
    if (p == null) return;
    remember();
    setState(() {
      bus.bookings.add(Booking(p.name, seat, p.priority));
    });
    widget.onChanged();
  }

  // The Book button: first free seat, or the waitlist if the bus is full.
  Future<void> addPassenger() async {
    if (!checkOpen()) return;
    final p = await askPassenger('New passenger');
    if (p == null) return;
    remember();
    final seat = firstFreeSeat(bus.bookings);
    setState(() {
      if (seat != null) {
        bus.bookings.add(Booking(p.name, seat, p.priority));
      } else {
        insertByPriority(bus.waitlist, p);
      }
    });
    widget.onChanged();
    showMessage(seat != null
        ? '${p.name} booked on seat $seat'
        : 'Bus full: ${p.name} added to the waitlist');
  }

  // Tap a booked seat: cancel it. The first person waiting gets the seat.
  Future<void> cancelSeat(Booking booking) async {
    if (!checkOpen()) return;
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cancel seat ${booking.seat}?'),
        content: Text('${booking.name} will lose this seat.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Cancel seat')),
        ],
      ),
    );
    if (yes != true) return;

    remember();
    var message = 'Seat ${booking.seat} is free';
    setState(() {
      bus.bookings.remove(booking);
      if (bus.waitlist.isNotEmpty) {
        final next = bus.waitlist.removeAt(0); // the front of the waitlist
        bus.bookings.add(Booking(next.name, booking.seat, next.priority));
        message = '${next.name} gets seat ${booking.seat}';
      }
    });
    widget.onChanged();
    showMessage(message);
  }

  void removeFromWaitlist(int index) {
    remember();
    final p = bus.waitlist[index];
    setState(() {
      bus.waitlist.removeAt(index);
    });
    widget.onChanged();
    showMessage('${p.name} removed from the waitlist');
  }

  // ---------------- Screen ----------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${bus.from} → ${bus.to}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo),
            tooltip: 'Undo',
            onPressed: undoBookings == null ? null : undo,
          ),
        ],
      ),
      floatingActionButton: bus.open
          ? FloatingActionButton.extended(
        onPressed: addPassenger,
        icon: const Icon(Icons.person_add),
        label: const Text('Book'),
      )
          : null,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
        children: [
          Text(
            '${bus.plate} · Departs ${bus.departure} · ${bus.statusLabel}',
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 12),
          buildWeatherCard(),
          if (!bus.open) buildClosedBanner(),
          const SizedBox(height: 16),
          Text(
            'Seats  (${bus.bookings.length}/$seatCount booked)',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          buildSeatMap(),
          const SizedBox(height: 8),
          const Text('Tap a free seat to book it, a booked seat to cancel it.'),
          const SizedBox(height: 20),
          Text(
            'Waitlist  (${bus.waitlist.length})',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          buildWaitlist(),
        ],
      ),
    );
  }

  // The API part: loading, error, data (checked in that order).
  Widget buildWeatherCard() {
    Widget content;
    if (loadingWeather) {
      content = const Center(child: CircularProgressIndicator());
    } else if (weatherError != null) {
      content = Row(
        children: [
          const Icon(Icons.wifi_off),
          const SizedBox(width: 12),
          Expanded(child: Text(weatherError!)),
          TextButton(onPressed: retryWeather, child: const Text('Retry')),
        ],
      );
    } else {
      final w = weather!;
      content = Row(
        children: [
          Icon(iconFor(w.code), size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${w.temperature.round()}°C · ${describe(w.code)}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text('Wind ${w.wind} km/h · Updated at ${w.clock}'),
              ],
            ),
          ),
        ],
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Weather in ${destination.name} today',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SizedBox(height: 56, child: content),
          ],
        ),
      ),
    );
  }

  Widget buildClosedBanner() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('Booking is closed: this bus is ${bus.statusLabel.toLowerCase()}.'),
    );
  }

  Widget buildSeatMap() {
    // GridView inside a ListView: shrinkWrap and no scrolling of its own.
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: [
        for (var seat = 1; seat <= seatCount; seat++) buildSeat(seat),
      ],
    );
  }

  Widget buildSeat(int seat) {
    final booking = bookingFor(bus.bookings, seat);
    Color color;
    if (booking == null) {
      color = Colors.green.shade100; // free
    } else if (booking.priority) {
      color = Colors.amber.shade300; // priority passenger
    } else {
      color = Colors.indigo.shade100; // booked
    }

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => booking == null ? bookSeat(seat) : cancelSeat(booking),
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.all(4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('$seat', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(
              booking == null ? 'Free' : booking.name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
            if (booking != null && booking.priority) const Icon(Icons.star, size: 14),
          ],
        ),
      ),
    );
  }

  Widget buildWaitlist() {
    if (bus.waitlist.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('Nobody is waiting.'),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < bus.waitlist.length; i++)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(child: Text('${i + 1}')),
            title: Text(bus.waitlist[i].name),
            subtitle: Text(bus.waitlist[i].priority ? 'Priority' : 'Normal'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (bus.waitlist[i].priority) const Icon(Icons.star, color: Colors.amber),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Remove',
                  onPressed: () => removeFromWaitlist(i),
                ),
              ],
            ),
          ),
      ],
    );
  }
}