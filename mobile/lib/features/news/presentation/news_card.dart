import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/portal_theme.dart';
import '../data/news_api_client.dart';

/// Card visual para exibir um [NewsArticle].
///
/// Ao ser pressionado, abre a URL do artigo no browser externo
/// usando [url_launcher].
class NewsCard extends StatelessWidget {
  const NewsCard({super.key, required this.article, this.onSummarize});

  final NewsArticle article;

  /// Callback acionado ao tocar em "Resumo com IA".
  /// Se nulo, o botão não aparece.
  final VoidCallback? onSummarize;

  Future<void> _open(BuildContext context) async {
    final url = Uri.tryParse(article.url);
    if (url == null || article.url.isEmpty) return;

    // launchUrl com mode externo garante que o artigo abre no browser
    // do sistema, não dentro do app (o que exigiria permissão de WebView).
    final launched = await launchUrl(url, mode: LaunchMode.externalApplication);

    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o link.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: PortalColors.darkWine,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: PortalColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _open(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Fonte + data
              Row(
                children: [
                  if (article.source != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: PortalColors.wine,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: PortalColors.border),
                      ),
                      child: Text(
                        article.source!,
                        style: const TextStyle(
                          color: PortalColors.gold,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (article.publishedAt != null)
                    Text(
                      _formatDate(article.publishedAt!),
                      style: const TextStyle(
                        color: PortalColors.muted,
                        fontSize: 11,
                      ),
                    ),
                  const Spacer(),
                  const Icon(
                    Icons.open_in_new,
                    size: 14,
                    color: PortalColors.muted,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Título
              Text(
                article.title,
                style: const TextStyle(
                  color: PortalColors.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              // Descrição
              if (article.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  article.description,
                  style: const TextStyle(
                    color: PortalColors.muted,
                    fontSize: 13,
                    height: 1.45,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              // Autor
              if (article.author != null && article.author!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  'Por ${article.author}',
                  style: const TextStyle(
                    color: PortalColors.muted,
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              // Ações: resumo com IA + abrir artigo
              const SizedBox(height: 12),
              Row(
                children: [
                  if (onSummarize != null)
                    TextButton.icon(
                      onPressed: onSummarize,
                      icon: const Icon(
                        Icons.auto_awesome,
                        color: PortalColors.gold,
                        size: 14,
                      ),
                      label: const Text(
                        'Resumo com IA',
                        style: TextStyle(
                          color: PortalColors.gold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => _open(context),
                    icon: const Icon(
                      Icons.open_in_new,
                      color: PortalColors.muted,
                      size: 14,
                    ),
                    label: const Text(
                      'Abrir',
                      style: TextStyle(color: PortalColors.muted, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Formata a data ISO 8601 para exibição legível (ex: "9 nov 2026").
  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      const months = [
        '',
        'jan',
        'fev',
        'mar',
        'abr',
        'mai',
        'jun',
        'jul',
        'ago',
        'set',
        'out',
        'nov',
        'dez',
      ];
      return '${dt.day} ${months[dt.month]} ${dt.year}';
    } on Exception {
      return iso;
    }
  }
}
