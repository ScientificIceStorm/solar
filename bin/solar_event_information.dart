import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;

const _host = 'events.vex.com';
const _eventPath = '/robot-competitions/vex-robotics-competition';
const _labels = {
  'generalinfo': 'General information',
  'generalinformation': 'General information',
  'agenda': 'Agenda',
  'volunteer': 'Volunteer',
  'emergencybadweatherpolicy': 'Emergency and weather policy',
  'refundandpaymentpolicies': 'Refund and payment policies',
  'webcast': 'Webcast',
  'webcasts': 'Webcast',
  'judgingformat': 'Judging format',
  'documents': 'Documents',
  'travelinfo': 'Travel information',
  'travelinformation': 'Travel information',
  'sustainability': 'Sustainability',
};

Uri solarOfficialEventUrl(String sku) =>
    Uri.https(_host, '$_eventPath/$sku.html');

Uri? solarPublicLink(Uri base, String? value) {
  if (value == null ||
      value.trim().isEmpty ||
      value.trimLeft().startsWith('#')) {
    return null;
  }
  final parsed = Uri.tryParse(value.trim());
  if (parsed == null) return null;
  final uri = base.resolveUri(parsed);
  return (uri.scheme == 'https' || uri.scheme == 'http') &&
          uri.path != '/cdn-cgi/l/email-protection' &&
          uri.host.isNotEmpty &&
          uri.userInfo.isEmpty &&
          uri != base
      ? uri
      : null;
}

Future<Document?> _readPage(Uri url) async {
  try {
    final response = await http.get(url).timeout(const Duration(seconds: 5));
    if (response.statusCode == 200 &&
        response.bodyBytes.length < 2 * 1024 * 1024) {
      return html.parse(response.body);
    }
  } on Exception {
    // An unavailable public page does not affect results from the official API.
  }
  return null;
}

Future<Map<String, dynamic>> solarEventInformation(
  String sku, {
  bool fallbacks = true,
}) async {
  final source = solarOfficialEventUrl(sku);
  final page = await _readPage(source);
  final sections = page == null
      ? <Map<String, Object>>[]
      : solarEventSections(page, source);
  final links = <String>{
    for (final section in sections)
      if (section['title'] == 'Webcast')
        for (final link in section['links'] as List<Map<String, String>>)
          link['url']!,
  };
  if (fallbacks && links.isEmpty) {
    links.addAll((await solarWebcastCatalog())[sku] ?? const []);
  }
  if (fallbacks && links.isEmpty) {
    links.addAll(await _mirroredWebcasts(sku));
  }
  return {
    'source': source.toString(),
    'sections': sections,
    'webcasts': links.toList(),
  };
}

String _key(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');

List<Map<String, Object>> solarEventSections(Document page, Uri source) {
  final containers = <String, Element>{};
  for (final tab in page.querySelectorAll(
    'a[href*="#"], [data-bs-target^="#"], [data-target^="#"], [aria-controls]',
  )) {
    final fragment =
        tab.attributes['data-bs-target'] ??
        tab.attributes['data-target'] ??
        tab.attributes['href'];
    final id = fragment?.contains('#') == true
        ? fragment!.split('#').last
        : tab.attributes['aria-controls'];
    if (id == null) continue;
    final title =
        _labels[_key(tab.text)] ??
        (_key(id).contains('agenda') ? 'Agenda' : null);
    if (title == null) continue;
    final pane = page.getElementById(id);
    if (pane != null) containers[title] = pane;
  }
  for (final heading in page.querySelectorAll('h2, h3, h4, h5, h6, summary')) {
    final title = _labels[_key(heading.text)];
    if (title == null || containers.containsKey(title)) continue;
    var pane = heading.parent;
    while (pane != null &&
        !pane.classes.contains('tab-pane') &&
        !pane.classes.contains('accordion-item') &&
        !const {'section', 'details'}.contains(pane.localName)) {
      pane = pane.parent;
    }
    if (pane != null &&
        pane
                .querySelectorAll('h2, h3, h4')
                .where((item) => _labels.containsKey(_key(item.text)))
                .length ==
            1) {
      containers[title] = pane;
      continue;
    }
    final content = Element.tag('div');
    var sibling = heading.nextElementSibling;
    while (sibling != null && !_labels.containsKey(_key(sibling.text))) {
      content.append(sibling.clone(true));
      sibling = sibling.nextElementSibling;
    }
    containers[title] = content;
  }

  return [
    for (final entry in containers.entries)
      if (entry.value.text.trim().isNotEmpty ||
          entry.value.querySelector('iframe') != null)
        {
          'title': entry.key,
          'text': _sectionText(entry.value.clone(true), entry.key),
          'links': _sectionLinks(
            entry.value,
            source,
            includeEmbeds: entry.key == 'Webcast',
          ),
        },
  ];
}

String _sectionText(Element element, String title) {
  for (final node in element.querySelectorAll(
    'script, style, template, noscript, form, iframe',
  )) {
    node.remove();
  }
  for (final node in element.querySelectorAll(
    'h1,h2,h3,h4,h5,p,li,br,div,tr',
  )) {
    if (_labels[_key(node.text)] == title &&
        RegExp(r'^h[1-5]$').hasMatch(node.localName ?? '')) {
      node.remove();
    } else {
      node.append(Text('\n'));
    }
  }
  return element.text
      .replaceAll(
        RegExp(r'\[email\s+protected\]', caseSensitive: false),
        '(see official event page for contact details)',
      )
      .replaceAll(RegExp(r'[\t\r ]+'), ' ')
      .replaceAll(RegExp(r' *\n[ \n]*'), '\n')
      .trim();
}

List<Map<String, String>> _sectionLinks(
  Element element,
  Uri source, {
  bool includeEmbeds = false,
}) {
  final links = <Uri, String>{};
  for (final node in element.querySelectorAll(
    includeEmbeds ? 'a[href], iframe[src]' : 'a[href]',
  )) {
    final href = Uri.tryParse(node.attributes['href'] ?? '');
    if (source.host == _host &&
        href != null &&
        source.resolveUri(href).path == '/cdn-cgi/l/email-protection') {
      links[source] = 'Contact the organizer on VEX Events';
      continue;
    }
    final url = solarPublicLink(
      source,
      node.attributes['href'] ?? node.attributes['src'],
    );
    if (url != null) links[url] = node.text.trim();
  }
  if (includeEmbeds) {
    for (final match in RegExp(
      r'https?://[^\s<>"\u00a0]+',
    ).allMatches(element.text)) {
      final url = solarPublicLink(
        source,
        match[0]!.replaceFirst(RegExp(r'[.,;)]+$'), ''),
      );
      if (url != null) links.putIfAbsent(url, () => '');
    }
  }
  return [
    for (final entry in links.entries)
      {
        'url': entry.key.toString(),
        'label': entry.value.isEmpty ? entry.key.host : entry.value,
      },
  ];
}

Future<Map<String, List<String>>>? _catalog;
DateTime? _catalogExpires;

Future<Map<String, List<String>>> solarWebcastCatalog() {
  final now = DateTime.now();
  if (_catalogExpires?.isAfter(now) ?? false) return _catalog!;
  _catalogExpires = now.add(const Duration(minutes: 10));
  return _catalog = _loadCatalog();
}

Future<Map<String, List<String>>> _loadCatalog() async {
  final url = Uri.https(_host, '/webcasts');
  final page = await _readPage(url);
  final result = <String, List<String>>{};
  if (page == null) return result;
  for (final row in page.querySelectorAll('tr')) {
    final sku = RegExp(
      r'\b(?:RE|VE)-[A-Z0-9]+-\d{2}-\d+\b',
    ).firstMatch(row.text)?[0];
    final cells = row.querySelectorAll('td');
    if (sku == null || cells.length < 2) continue;
    final links = _sectionLinks(cells.last, url, includeEmbeds: true);
    if (links.isNotEmpty) {
      result[sku] = links.map((link) => link['url']!).toList();
    }
  }
  return result;
}

Future<List<String>> _mirroredWebcasts(String sku) async {
  // This public event index retains organizer links after VEX rotates its list.
  final url = Uri.https('www.vrchq.app', '/event/$sku');
  final page = await _readPage(url);
  if (page == null) return [];
  for (final heading in page.querySelectorAll('h2')) {
    if (_key(heading.text) != 'webcast') continue;
    final panel = heading.parent;
    if (panel == null ||
        !panel.text.contains(
          'Posted by the Event Partner on events.vex.com/webcasts',
        )) {
      continue;
    }
    return _sectionLinks(panel, url).map((link) => link['url']!).toList();
  }
  return [];
}
