import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/portal_theme.dart';
import '../data/news_api_client.dart';

/// Tela que exibe o resumo de um artigo individual gerado por IA.
///
/// Recebe o [article] e o [apiClient] da tela de notícias. Ao ser aberta,
/// chama POST /api/news/summarize para gerar o resumo, depois
/// GET /api/news/summaries/:id para exibir o resultado completo.
class ArticleSummaryScreen extends StatefulWidget {
  const ArticleSummaryScreen({
    super.key,
    required this.article,
    required this.apiClient,
  });

  final NewsArticle article;
  final NewsApiClient apiClient;

  @override
  State<ArticleSummaryScreen> createState() => _ArticleSummaryScreenState();
}

class _ArticleSummaryScreenState extends State<ArticleSummaryScreen> {
  bool _loading = true;
  String? _error;
  ArticleSummary? _summary;

  @override
  void initState() {
    super.initState();
    _generateSummary();
  }

  Future<void> _generateSummary() async {
    // Step 1: Solicita a geração do resumo → recebe { summaryId }
    final request = await widget.apiClient.summarizeArticle(widget.article);

    if (!mounted) return;

    if (!request.ok || request.summaryId == null) {
      setState(() {
        _loading = false;
        _error = request.message ?? 'Não foi possível gerar o resumo.';
      });
      return;
    }

    // Step 2: Busca o resumo completo pelo ID
    final fetch = await widget.apiClient.getArticleSummary(request.summaryId!);

    if (!mounted) return;

    if (fetch.ok && fetch.summary != null) {
      setState(() {
        _loading = false;
        _summary = fetch.summary;
      });
    } else {
      setState(() {
        _loading = false;
        _error = fetch.message ?? 'Não foi possível carregar o resumo.';
      });
    }
  }

  Future<void> _openArticle() async {
    final url = Uri.tryParse(widget.article.url);
    if (url == null || widget.article.url.isEmpty) return;
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PortalColors.background,
      appBar: AppBar(
        backgroundColor: PortalColors.darkWine,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: PortalColors.muted),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Resumo com IA',
          style: TextStyle(
            color: PortalColors.goldLight,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: _loading
          ? _buildLoading()
          : _error != null
          ? _buildError()
          : _summary != null
          ? _buildSummary()
          : const SizedBox.shrink(),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_awesome, color: PortalColors.gold, size: 48),
          const SizedBox(height: 20),
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: PortalColors.gold,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Gerando resumo com IA…',
            style: TextStyle(color: PortalColors.muted, fontSize: 14),
          ),
          const SizedBox(height: 8),
          const Text(
            'Isso pode levar alguns segundos enquanto a IA lê o artigo.',
            style: TextStyle(color: PortalColors.muted, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: PortalColors.danger,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(color: PortalColors.danger, fontSize: 15),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _loading = true;
                  _error = null;
                });
                _generateSummary();
              },
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Tentar novamente'),
              style: ElevatedButton.styleFrom(
                backgroundColor: PortalColors.wine,
                foregroundColor: PortalColors.gold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary() {
    final s = _summary!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Imagem (se disponível)
        if (s.urlToImage != null && s.urlToImage!.isNotEmpty) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.network(
              s.urlToImage!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
          const SizedBox(height: 16),
        ],
        // Fonte + data
        Row(
          children: [
            if (s.source != null && s.source!.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: PortalColors.wine,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: PortalColors.border),
                ),
                child: Text(
                  s.source!,
                  style: const TextStyle(
                    color: PortalColors.gold,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            if (s.publishedAt != null)
              Text(
                _formatDate(s.publishedAt!),
                style: const TextStyle(color: PortalColors.muted, fontSize: 11),
              ),
          ],
        ),
        const SizedBox(height: 12),
        // Título
        Text(
          s.title,
          style: const TextStyle(
            color: PortalColors.text,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            height: 1.3,
          ),
        ),
        if (s.author != null && s.author!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Por ${s.author}',
            style: const TextStyle(
              color: PortalColors.muted,
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
        const SizedBox(height: 20),
        // Divisor
        Container(
          height: 1,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [PortalColors.wine, PortalColors.gold, PortalColors.wine],
            ),
          ),
        ),
        const SizedBox(height: 20),
        // Label do resumo
        Row(
          children: [
            const Icon(Icons.auto_awesome, color: PortalColors.gold, size: 16),
            const SizedBox(width: 8),
            const Text(
              'Resumo gerado por IA',
              style: TextStyle(
                color: PortalColors.gold,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Texto do resumo (parágrafos)
        ...s.summary
            .split('\n\n')
            .where((p) => p.trim().isNotEmpty)
            .map(
              (paragraph) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  paragraph.trim(),
                  style: const TextStyle(
                    color: PortalColors.text,
                    fontSize: 15,
                    height: 1.6,
                  ),
                ),
              ),
            ),
        // Metadados da IA
        if (s.model != null && s.model!.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: PortalColors.field,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: PortalColors.border),
            ),
            child: Text(
              'Modelo: ${s.model}',
              style: const TextStyle(color: PortalColors.muted, fontSize: 11),
            ),
          ),
        ],
        const SizedBox(height: 24),
        // Botão: abrir artigo original
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _openArticle,
            icon: const Icon(Icons.open_in_new, size: 18),
            label: const Text('Abrir artigo original'),
            style: ElevatedButton.styleFrom(
              backgroundColor: PortalColors.wine,
              foregroundColor: PortalColors.gold,
            ),
          ),
        ),
      ],
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
