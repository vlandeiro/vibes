// ics.js — generate and download an ICS calendar file for a week's meals

function generateICS(weekKey) {
  var monday = getMondayOfWeek(weekKey);
  var week = state.weeks[weekKey] || {};
  var times = state.settings.mealTimes || {};
  var mealOrder = ['lunch', 'dinner', 'snacks'];
  var mealLabels = { lunch: 'Lunch', dinner: 'Dinner', snacks: 'Snacks' };

  var defaultTimes = {
    lunch:  { start: '12:00', end: '13:00' },
    dinner: { start: '18:00', end: '19:00' },
    snacks: { start: '15:00', end: '15:30' }
  };

  var events = [];

  for (var d = 0; d < 7; d++) {
    var date = new Date(monday);
    date.setDate(monday.getDate() + d);
    var day = week[String(d)] || {};

    mealOrder.forEach(function (meal) {
      var text = day[meal] || '';
      if (!text.trim()) return;

      var isOut = !!day[meal + 'Out'];
      var label = mealLabels[meal];
      var summary = label + ': ' + text + (isOut ? ' (Dining Out)' : '');

      var mealTime = (times[meal]) || defaultTimes[meal];
      var dtstart = formatICSDateTime(date, mealTime.start);
      var dtend   = formatICSDateTime(date, mealTime.end);

      events.push([
        'BEGIN:VEVENT',
        'UID:mealplanner-' + weekKey + '-' + d + '-' + meal + '@vibes',
        'DTSTART:' + dtstart,
        'DTEND:' + dtend,
        'SUMMARY:' + escapeICS(summary),
        'END:VEVENT'
      ].join('\r\n'));
    });
  }

  if (events.length === 0) return null;

  var lines = [
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//Meal Planner//vibes//EN',
    'CALSCALE:GREGORIAN',
    'METHOD:PUBLISH'
  ];
  lines = lines.concat(events);
  lines.push('END:VCALENDAR');

  return lines.join('\r\n');
}

function formatICSDateTime(date, timeStr) {
  // timeStr: "HH:MM"
  var parts = timeStr.split(':');
  var hh = (parts[0] || '00').padStart(2, '0');
  var mm = (parts[1] || '00').padStart(2, '0');
  var y = String(date.getFullYear());
  var mo = String(date.getMonth() + 1).padStart(2, '0');
  var d = String(date.getDate()).padStart(2, '0');
  return y + mo + d + 'T' + hh + mm + '00';
}

function escapeICS(str) {
  return str.replace(/\\/g, '\\\\').replace(/;/g, '\\;').replace(/,/g, '\\,').replace(/\n/g, '\\n');
}

function downloadICS(weekKey) {
  var content = generateICS(weekKey);
  if (!content) {
    alert('No meals planned for this week to export.');
    return;
  }
  var blob = new Blob([content], { type: 'text/calendar;charset=utf-8' });
  var a = document.createElement('a');
  a.href = URL.createObjectURL(blob);
  a.download = 'meal-plan-' + weekKey + '.ics';
  document.body.appendChild(a);
  a.click();
  setTimeout(function () { URL.revokeObjectURL(a.href); a.remove(); }, 100);
}
