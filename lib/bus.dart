// The bus model and its rules. No widgets here.

const seatCount = 12;

// A bus moves through these statuses, in order.
const statuses = ['Waiting', 'On the road', 'Arrived'];

// ---------------- A passenger with a seat ----------------

class Booking {
  Booking(this.name, this.seat, this.priority);

  final String name;
  final int seat; // 1 to seatCount
  final bool priority; // elderly, pregnant, disability...

  Map<String, dynamic> toJson() {
    return {'name': name, 'seat': seat, 'priority': priority};
  }

  factory Booking.fromJson(Map<String, dynamic> json) {
    return Booking(
      json['name'] as String,
      (json['seat'] as num).toInt(),
      json['priority'] as bool,
    );
  }
}

// ---------------- A passenger waiting for a seat ----------------

class Passenger {
  Passenger(this.name, this.priority);

  final String name;
  final bool priority;

  Map<String, dynamic> toJson() {
    return {'name': name, 'priority': priority};
  }

  factory Passenger.fromJson(Map<String, dynamic> json) {
    return Passenger(json['name'] as String, json['priority'] as bool);
  }
}

// ---------------- A bus: its trip, its seats, its waitlist ----------------

class Bus {
  Bus(this.plate, this.from, this.to, this.departure, this.status,
      this.bookings, this.waitlist);

  final String plate; // "RAC 123 B"
  final String from; // "Kigali", "Huye", "Musanze" or "Rubavu"
  final String to;
  final String departure; // "08:30"
  final int status; // index in statuses: 0, 1 or 2
  final List<Booking> bookings; // the list itself can change (add, remove)
  final List<Passenger> waitlist;

  String get statusLabel => statuses[status];
  int get freeSeats => seatCount - bookings.length;
  bool get open => status == 0; // you can only book while the bus is waiting

  // The same bus, one status further (keeps the same passengers).
  // After "Arrived" it goes back to "Waiting" for its next trip.
  Bus next() {
    return Bus(plate, from, to, departure, (status + 1) % statuses.length,
        bookings, waitlist);
  }

  // Bus -> Map. The passengers become lists of Maps inside it.
  Map<String, dynamic> toJson() {
    return {
      'plate': plate,
      'from': from,
      'to': to,
      'departure': departure,
      'status': status,
      'bookings': bookings.map((b) => b.toJson()).toList(),
      'waitlist': waitlist.map((p) => p.toJson()).toList(),
    };
  }

  // Map -> Bus. `?? []` keeps old saved buses (with no passengers) working.
  factory Bus.fromJson(Map<String, dynamic> json) {
    final savedBookings = json['bookings'] as List? ?? [];
    final savedWaitlist = json['waitlist'] as List? ?? [];
    return Bus(
      json['plate'] as String,
      json['from'] as String,
      json['to'] as String,
      json['departure'] as String,
      (json['status'] as num).toInt(),
      savedBookings.map((x) => Booking.fromJson(x as Map<String, dynamic>)).toList(),
      savedWaitlist.map((x) => Passenger.fromJson(x as Map<String, dynamic>)).toList(),
    );
  }
}

// ---------------- Rules ----------------

// The booking on this seat, or null if the seat is free.
Booking? bookingFor(List<Booking> bookings, int seat) {
  for (final b in bookings) {
    if (b.seat == seat) return b;
  }
  return null;
}

// The smallest free seat number, or null if the bus is full.
int? firstFreeSeat(List<Booking> bookings) {
  for (var seat = 1; seat <= seatCount; seat++) {
    if (bookingFor(bookings, seat) == null) return seat;
  }
  return null;
}

// Normal passengers join the back of the waitlist.
// A priority passenger goes ahead of every normal passenger,
// but behind the priority passengers already waiting.
void insertByPriority(List<Passenger> waitlist, Passenger p) {
  if (!p.priority) {
    waitlist.add(p);
    return;
  }
  var position = 0;
  while (position < waitlist.length && waitlist[position].priority) {
    position++;
  }
  waitlist.insert(position, p);
}

// ---------------- Sample data (first launch only) ----------------

List<Bus> sampleBuses() {
  const names = [
    'Ange', 'Eric', 'Diane', 'Peter', 'Sandrine', 'Jean',
    'Aline', 'Claude', 'Grace', 'Olivier', 'Divine', 'Patrick',
  ];
  return [
    // A full bus, with two people waiting
    Bus('RAC 123 B', 'Kigali', 'Huye', '07:00', 0,
        [for (var s = 1; s <= seatCount; s++) Booking(names[s - 1], s, s == 3 || s == 9)],
        [Passenger('Mama Uwase', true), Passenger('Kevin', false)]),
    Bus('RAD 456 A', 'Kigali', 'Musanze', '08:30', 0,
        [Booking('Ange', 1, false), Booking('Eric', 2, true)], []),
    Bus('RAE 789 C', 'Kigali', 'Rubavu', '10:00', 1,
        [Booking('Peter', 1, false), Booking('Jean', 5, false)], []),
    Bus('RAB 321 D', 'Huye', 'Kigali', '11:15', 0, [], []),
    Bus('RAF 654 E', 'Musanze', 'Rubavu', '13:00', 0, [Booking('Aline', 4, false)], []),
  ];
}