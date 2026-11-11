import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../../auth/data/auth_api_client.dart';

/// Representa um artigo de notícia retornado pelo News Service.
///
/// O backend devolve o formato da NewsAPI.org com alguns campos extras.
/// O [shortId] é gerado client-side (não vem do backend) e usado para
/// vincular trechos da síntese de IA a artigos específicos.
class NewsArticle {
  const NewsArticle({
    required this.title,
    required this.description,
    required this.url,
    this.shortId,
    this.source,
    this.author,
    this.publishedAt,
    this.urlToImage,
  });

  final String title;
  final String description;
  final String url;
  final String? shortId;
  final String? source;
  final String? author;
  final String? publishedAt;
  final String? urlToImage;

  factory NewsArticle.fromJson(Map<String, dynamic> json) => NewsArticle(
    title: (json['title'] as String?)?.trim() ?? 'Sem título',
    description: (json['description'] as String?)?.trim() ?? '',
    url: json['url'] as String? ?? '',
    shortId: json['shortId'] as String?,
    // O backend Node.js já transforma source em string
    // (article.source?.name), mas mantemos compatibilidade com o
    // formato original da NewsAPI (source como objeto {name}).
    source: json['source'] is Map
        ? (json['source'] as Map)['name'] as String?
        : json['source'] as String?,
    author: json['author'] as String?,
    publishedAt: json['publishedAt'] as String?,
    urlToImage: json['urlToImage'] as String?,
  );

  /// Cria uma cópia com um novo [shortId].
  NewsArticle withShortId(String id) => NewsArticle(
    title: title,
    description: description,
    url: url,
    shortId: id,
    source: source,
    author: author,
    publishedAt: publishedAt,
    urlToImage: urlToImage,
  );
}

/// Gera um shortId aleatório de 6 caracteres (base36), evitando colisões.
String _createShortId(Set<String> existing) {
  final random = Random();
  String candidate;
  do {
    candidate = '';
    for (var i = 0; i < 6; i++) {
      candidate += random.nextInt(36).toRadixString(36);
    }
  } while (candidate.isEmpty || existing.contains(candidate));
  return candidate;
}

/// Atribui um [shortId] único a cada artigo que ainda não possui um.
///
/// O backend não retorna shortIds — eles são gerados client-side,
/// igual ao frontend web (NewsSearch.tsx → attachShortIds).
List<NewsArticle> attachShortIds(List<NewsArticle> articles) {
  final usedIds = <String>{};
  return articles.map((article) {
    final id = (article.shortId != null && article.shortId!.isNotEmpty)
        ? article.shortId!
        : _createShortId(usedIds);
    usedIds.add(id);
    return article.withShortId(id);
  }).toList();
}

/// Resultado de uma busca de notícias.
class NewsResult {
  const NewsResult.success({
    required this.articles,
    required this.totalResults,
    required this.page,
  }) : ok = true,
       message = null;

  const NewsResult.failure(this.message)
    : ok = false,
      articles = const [],
      totalResults = 0,
      page = 1;

  final bool ok;
  final List<NewsArticle> articles;
  final int totalResults;
  final int page;
  final String? message;

  bool get hasMore => articles.length >= 20;
}

/// Um trecho da síntese de IA vinculado a um artigo específico.
class SummarySegment {
  const SummarySegment({required this.shortId, required this.text});

  final String shortId;
  final String text;

  factory SummarySegment.fromJson(Map<String, dynamic> json) => SummarySegment(
    shortId: json['shortId'] as String? ?? '',
    text: json['text'] as String? ?? '',
  );
}

/// Resultado da síntese de página com IA.
class NewsSummaryResult {
  const NewsSummaryResult.success({
    required this.summary,
    this.markedSummary,
    this.segments,
  }) : ok = true,
       message = null;

  const NewsSummaryResult.failure(this.message)
    : ok = false,
      summary = '',
      markedSummary = null,
      segments = null;

  final bool ok;
  final String summary;
  final String? markedSummary;
  final List<SummarySegment>? segments;
  final String? message;
}

/// Resumo de um artigo individual gerado por IA.
///
/// O Article Summary Service extrai o conteúdo da URL do artigo,
/// envia para a IA (OpenRouter) e armazena o resultado no banco.
/// O resumo pode ser recuperado pelo [id] (UUID).
class ArticleSummary {
  const ArticleSummary({
    required this.id,
    required this.title,
    required this.summary,
    this.author,
    this.source,
    this.publishedAt,
    this.urlToImage,
    this.url,
    this.provider,
    this.model,
    this.createdAt,
  });

  final String id;
  final String title;
  final String summary;
  final String? author;
  final String? source;
  final String? publishedAt;
  final String? urlToImage;
  final String? url;
  final String? provider;
  final String? model;
  final String? createdAt;

  factory ArticleSummary.fromJson(Map<String, dynamic> json) => ArticleSummary(
    id: json['id'] as String? ?? '',
    title: json['title'] as String? ?? 'Sem título',
    summary: json['summary'] as String? ?? '',
    author: json['author'] as String?,
    source: json['source'] as String?,
    publishedAt: json['publishedAt'] as String?,
    urlToImage: json['urlToImage'] as String?,
    url: json['url'] as String?,
    provider: json['provider'] as String?,
    model: json['model'] as String?,
    createdAt: json['createdAt'] as String?,
  );
}

/// Resultado da solicitação de resumo (POST /api/news/summarize).
class ArticleSummaryRequestResult {
  const ArticleSummaryRequestResult.success({required this.summaryId})
    : ok = true,
      message = null;

  const ArticleSummaryRequestResult.failure(this.message)
    : ok = false,
      summaryId = null;

  final bool ok;
  final String? summaryId;
  final String? message;
}

/// Resultado da busca de resumo (GET /api/news/summaries/:id).
class ArticleSummaryFetchResult {
  const ArticleSummaryFetchResult.success({required this.summary})
    : ok = true,
      message = null;

  const ArticleSummaryFetchResult.failure(this.message)
    : ok = false,
      summary = null;

  final bool ok;
  final ArticleSummary? summary;
  final String? message;
}

/// Cliente HTTP para o News Service, roteado pelo gateway (porta 3000).
///
/// Rotas utilizadas:
/// - POST /api/news/search (busca paginada)
/// - POST /api/news-summary (síntese de página com IA)
/// - POST /api/news/summarize (resumo individual de artigo)
/// - GET /api/news/summaries/:id (busca resumo armazenado)
///
/// Todas requerem autenticação (cookie portal_session).
class NewsApiClient {
  /// Recebe o [CookieJarClient] já autenticado do [AuthApiClient]
  /// para reutilizar o cookie de sessão — não abrimos uma nova conexão.
  NewsApiClient({required CookieJarClient cookieJar}) : _jar = cookieJar;

  final CookieJarClient _jar;

  Uri _uri(String path) => Uri.parse('${ApiConfig.baseUrl}$path');

  /// Busca notícias com paginação.
  ///
  /// [query] é o termo de busca.
  /// [page] começa em 1. O backend retorna 20 artigos por página.
  Future<NewsResult> search(String query, {int page = 1}) async {
    try {
      final response = await _jar.post(
        _uri('/api/news/search'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({'query': query.trim(), 'page': page}),
      );

      if (response.statusCode == 401) {
        return const NewsResult.failure(
          'Sessão expirada. Faça login novamente.',
        );
      }

      if (response.statusCode != 200) {
        final body = _parseBody(response);
        final msg = body['message'];
        return NewsResult.failure(
          msg is String && msg.isNotEmpty
              ? msg
              : 'Erro ao buscar notícias (HTTP ${response.statusCode}).',
        );
      }

      final body = _parseBody(response);
      final rawArticles = body['articles'];
      final total = body['totalResults'];

      final articles = rawArticles is List
          ? rawArticles
                .whereType<Map<String, dynamic>>()
                .map(NewsArticle.fromJson)
                .toList()
          : <NewsArticle>[];

      return NewsResult.success(
        articles: articles,
        totalResults: total is int ? total : articles.length,
        page: page,
      );
    } on Exception {
      return const NewsResult.failure(
        'Não foi possível conectar ao servidor. Verifique sua conexão.',
      );
    }
  }

  /// Gera uma síntese central da página de resultados usando IA.
  ///
  /// Envia a query e os artigos (com seus shortIds) para o News Summary
  /// Service. O backend chama o AI Service (OpenRouter) e retorna:
  /// - [summary]: texto limpo sem marcações
  /// - [markedSummary]: texto com marcações [[trecho]]((shortId))
  /// - [segments]: trechos parseados vinculados a artigos
  Future<NewsSummaryResult> summarizePage(
    String query,
    List<NewsArticle> articles,
  ) async {
    try {
      final response = await _jar.post(
        _uri('/api/news-summary'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({
          'query': query.trim(),
          'articles': articles
              .where((a) => a.title.isNotEmpty || a.description.isNotEmpty)
              .map(
                (a) => {
                  'shortId': a.shortId ?? '',
                  'title': a.title,
                  'description': a.description,
                  'source': a.source ?? '',
                  'publishedAt': a.publishedAt ?? '',
                },
              )
              .toList(),
        }),
      );

      if (response.statusCode == 401) {
        return const NewsSummaryResult.failure(
          'Sessão expirada. Faça login novamente.',
        );
      }

      if (response.statusCode != 200) {
        final body = _parseBody(response);
        final msg = body['message'];
        return NewsSummaryResult.failure(
          msg is String && msg.isNotEmpty
              ? msg
              : 'Não foi possível gerar o resumo da página.',
        );
      }

      final body = _parseBody(response);
      final summary = body['summary'] as String? ?? '';
      final markedSummary = body['markedSummary'] as String?;
      final rawSegments = body['segments'];

      final segments = rawSegments is List
          ? rawSegments
                .whereType<Map<String, dynamic>>()
                .map(SummarySegment.fromJson)
                .where((s) => s.shortId.isNotEmpty && s.text.isNotEmpty)
                .toList()
          : <SummarySegment>[];

      return NewsSummaryResult.success(
        summary: summary,
        markedSummary: markedSummary,
        segments: segments,
      );
    } on Exception {
      return const NewsSummaryResult.failure(
        'Serviço de IA indisponível para resumir esta página.',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Resumo individual de artigo — POST /api/news/summarize
  // ---------------------------------------------------------------------------

  /// Solicita um resumo individual de artigo via IA.
  ///
  /// O Article Summary Service extrai o conteúdo da URL do artigo,
  /// envia para a IA (OpenRouter) e retorna { summaryId }.
  Future<ArticleSummaryRequestResult> summarizeArticle(
    NewsArticle article,
  ) async {
    try {
      final response = await _jar.post(
        _uri('/api/news/summarize'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({
          'title': article.title,
          'url': article.url,
          'author': article.author ?? '',
          'urlToImage': article.urlToImage ?? '',
          'description': article.description,
          'source': article.source ?? '',
          'publishedAt': article.publishedAt ?? '',
        }),
      );

      if (response.statusCode == 401) {
        return const ArticleSummaryRequestResult.failure(
          'Sessão expirada. Faça login novamente.',
        );
      }

      final body = _parseBody(response);
      if (response.statusCode == 200) {
        final summaryId = body['summaryId'] as String?;
        if (summaryId != null && summaryId.isNotEmpty) {
          return ArticleSummaryRequestResult.success(summaryId: summaryId);
        }
        return const ArticleSummaryRequestResult.failure(
          'Resumo gerado, mas o ID não foi retornado.',
        );
      }

      final msg = body['message'];
      return ArticleSummaryRequestResult.failure(
        msg is String && msg.isNotEmpty
            ? msg
            : 'Não foi possível gerar o resumo (HTTP ${response.statusCode}).',
      );
    } on Exception {
      return const ArticleSummaryRequestResult.failure(
        'Não foi possível conectar ao servidor. Verifique sua conexão.',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Busca de resumo armazenado — GET /api/news/summaries/:id
  // ---------------------------------------------------------------------------

  /// Busca um resumo de artigo pelo seu ID (UUID).
  ///
  /// O Article Summary Service retorna o resumo completo armazenado
  /// no banco, com título, texto, fonte, autor e metadados da IA.
  Future<ArticleSummaryFetchResult> getArticleSummary(String id) async {
    try {
      final response = await _jar.get(_uri('/api/news/summaries/$id'));

      if (response.statusCode == 401) {
        return const ArticleSummaryFetchResult.failure(
          'Sessão expirada. Faça login novamente.',
        );
      }

      if (response.statusCode == 404) {
        return const ArticleSummaryFetchResult.failure(
          'Resumo não encontrado.',
        );
      }

      if (response.statusCode != 200) {
        return ArticleSummaryFetchResult.failure(
          'Erro ao carregar o resumo (HTTP ${response.statusCode}).',
        );
      }

      final body = _parseBody(response);
      return ArticleSummaryFetchResult.success(
        summary: ArticleSummary.fromJson(body),
      );
    } on Exception {
      return const ArticleSummaryFetchResult.failure(
        'Não foi possível conectar ao servidor. Verifique sua conexão.',
      );
    }
  }

  Map<String, dynamic> _parseBody(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
    } on Exception {
      // body inválido
    }
    return {};
  }
}
