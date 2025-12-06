import 'package:xml/xml.dart';

void main() {
  final input = '''<style>
        <![CDATA[
            .st0{fill:blue;}
        ]]>
    </style>''';

  final doc = XmlDocument.parse(input);
  print('Children count: ${doc.rootElement.children.length}');
  for (final node in doc.rootElement.children) {
    print('Type: ${node.runtimeType}');
    if (node is XmlCDATA) {
      print('innerText: "${node.innerText}"');
      print('value: "${node.value}"');
    } else if (node is XmlText) {
      print('value: "${node.value}"');
    }
  }
}
