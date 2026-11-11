import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/portal_theme.dart';
import '../../auth/data/auth_api_client.dart';
import '../../news/data/news_api_client.dart';
import '../data/admin_api_client.dart';

/// Painel administrativo do Portal Escarlate.
///
/// Duas abas:
/// 1. Métricas — temas mais buscados com barras proporcionais
/// 2. Conexões — lista de contas Gmail + botão de conectar nova conta
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key, required this.authApiClient});

  final AuthApiClient authApiClient;

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late final NewsApiClient _news;
  late final AdminApiClient _admin;

  // Estado da aba Métricas
  NewsMetrics? _metrics;
  bool _metricsLoading = true;
  String? _metricsError;

  // Estado da aba Conexões
  List<EmailConnection> _connections = [];
  bool _connectionsLoading = true;
  String? _connectionsError;
  bool _oauthLoading = false;

  // ID da conexão cuja prioridade está sendo atualizada (null = nenhuma)
  String? _updatingPriorityId;

  @override
  void initState() {
    super.initState();
    _news = NewsApiClient(cookieJar: widget.authApiClient.jar);
    _admin = AdminApiClient(cookieJar: widget.authApiClient.jar);
    _loadMetrics();
    _loadConnections();
  }

  // ---------------------------------------------------------------------------
  // Carregamento de dados
  // ---------------------------------------------------------------------------

  Future<void> _loadMetrics() async {
    final result = await _news.getNewsMetrics();
    if (!mounted) return;
    setState(() {
      _metricsLoading = false;
      if (result.ok && result.metrics != null) {
        _metrics = result.metrics;
      } else {
        _metricsError = result.message;
      }
    });
  }

  Future<void> _loadConnections() async {
    final result = await _admin.getEmailConnections();
    if (!mounted) return;
    setState(() {
      _connectionsLoading = false;
      if (result.ok) {
        _connections = result.connections;
      } else {
        _connectionsError = result.message;
      }
    });
  }

  Future<void> _startGoogleOAuth() async {
    setState(() => _oauthLoading = true);

    final result = await _admin.startGoogleOAuth();

    if (!mounted) return;

    if (result.ok && result.url != null) {
      await launchUrl(
        Uri.parse(result.url!),
        mode: LaunchMode.externalApplication,
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? 'Erro ao iniciar OAuth.')),
      );
    }

    setState(() => _oauthLoading = false);
  }

  Future<void> _deleteConnection(String id) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: PortalColors.darkWine,
            title: const Text(
              'Remover conexão?',
              style: TextStyle(color: PortalColors.text),
            ),
            content: const Text(
              'A conexão de e-mail será removida permanentemente.',
              style: TextStyle(color: PortalColors.muted),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Remover',
                  style: TextStyle(color: PortalColors.danger),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    final success = await _admin.deleteConnection(id);
    if (!mounted) return;

    if (success) {
      setState(() {
        _connections.removeWhere((c) => c.id == id);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível remover a conexão.')),
      );
    }
  }

  Future<void> _updatePriority(String id, int priority) async {
    setState(() => _updatingPriorityId = id);

    final success = await _admin.updateConnectionPriority(id, priority);

    if (!mounted) return;
    setState(() => _updatingPriorityId = null);

    if (success) {
      _loadConnections();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível atualizar a prioridade.'),
        ),
      );
    }
  }

  Future<void> _editPriority(EmailConnection conn) async {
    final controller = TextEditingController(text: conn.priority.toString());

    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: PortalColors.darkWine,
        title: const Text(
          'Editar prioridade',
          style: TextStyle(color: PortalColors.text, fontSize: 16),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: PortalColors.text),
          decoration: const InputDecoration(
            labelText: 'Prioridade (mínimo 1)',
            labelStyle: TextStyle(color: PortalColors.muted),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: PortalColors.border),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: PortalColors.gold),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              final value = int.tryParse(controller.text);
              if (value != null && value >= 1) {
                Navigator.pop(context, value);
              }
            },
            child: const Text(
              'Salvar',
              style: TextStyle(color: PortalColors.gold),
            ),
          ),
        ],
      ),
    );

    controller.dispose();

    if (result != null && result != conn.priority) {
      await _updatePriority(conn.id, result);
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: PortalColors.background,
        appBar: AppBar(
          backgroundColor: PortalColors.darkWine,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: PortalColors.muted),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Painel admin',
            style: TextStyle(
              color: PortalColors.goldLight,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          bottom: const TabBar(
            indicatorColor: PortalColors.gold,
            labelColor: PortalColors.gold,
            unselectedLabelColor: PortalColors.muted,
            tabs: [
              Tab(icon: Icon(Icons.bar_chart), text: 'Métricas'),
              Tab(icon: Icon(Icons.mail), text: 'Conexões'),
            ],
          ),
        ),
        body: TabBarView(
          children: [_buildMetricsTab(), _buildConnectionsTab()],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Aba Métricas
  // -------------------------------------------------------------------------

  Widget _buildMetricsTab() {
    if (_metricsLoading) {
      return const Center(
        child: CircularProgressIndicator(color: PortalColors.gold),
      );
    }

    if (_metricsError != null) {
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
                _metricsError!,
                style: const TextStyle(color: PortalColors.danger),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _metricsLoading = true;
                    _metricsError = null;
                  });
                  _loadMetrics();
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

    final m = _metrics;
    if (m == null || m.themes.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.bar_chart_outlined,
              color: PortalColors.muted,
              size: 48,
            ),
            const SizedBox(height: 16),
            const Text(
              'Nenhuma métrica disponível ainda.',
              style: TextStyle(color: PortalColors.muted),
            ),
          ],
        ),
      );
    }

    final maxSearches = m.themes.fold<int>(
      0,
      (max, t) => t.totalSearches > max ? t.totalSearches : max,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Total de buscas
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: PortalColors.darkWine,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: PortalColors.border),
          ),
          child: Row(
            children: [
              const Icon(Icons.search, color: PortalColors.gold, size: 28),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total de buscas',
                      style: TextStyle(color: PortalColors.muted, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${m.totalSearches}',
                      style: const TextStyle(
                        color: PortalColors.goldLight,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Label
        const Text(
          'Temas mais buscados',
          style: TextStyle(
            color: PortalColors.gold,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        // Barras de temas
        ...m.themes.map((t) => _buildThemeBar(t, maxSearches)),
        if (m.users.isNotEmpty) ...[
          const SizedBox(height: 24),
          const Text(
            'Atividade por usuário',
            style: TextStyle(
              color: PortalColors.gold,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ...m.users.map(_buildUserRow),
        ],
      ],
    );
  }

  Widget _buildThemeBar(ThemeMetric theme, int maxSearches) {
    final fraction = maxSearches > 0
        ? (theme.totalSearches / maxSearches).clamp(0.04, 1.0)
        : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  theme.theme,
                  style: const TextStyle(
                    color: PortalColors.text,
                    fontSize: 13,
                  ),
                ),
              ),
              Text(
                '${theme.totalSearches}',
                style: const TextStyle(
                  color: PortalColors.goldLight,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: FractionallySizedBox(
              widthFactor: fraction.toDouble(),
              child: Container(
                height: 8,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [PortalColors.wine, PortalColors.gold],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${theme.uniqueUsers} usuário${theme.uniqueUsers != 1 ? 's' : ''}',
            style: const TextStyle(color: PortalColors.muted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildUserRow(UserMetric user) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.person_outline, color: PortalColors.muted, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              user.email,
              style: const TextStyle(color: PortalColors.text, fontSize: 13),
            ),
          ),
          Text(
            '${user.totalSearches} busca${user.totalSearches != 1 ? 's' : ''}',
            style: const TextStyle(color: PortalColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Aba Conexões
  // -------------------------------------------------------------------------

  Widget _buildConnectionsTab() {
    if (_connectionsLoading) {
      return const Center(
        child: CircularProgressIndicator(color: PortalColors.gold),
      );
    }

    if (_connectionsError != null) {
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
                _connectionsError!,
                style: const TextStyle(color: PortalColors.danger),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _connectionsLoading = true;
                    _connectionsError = null;
                  });
                  _loadConnections();
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

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Botão conectar Google
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _oauthLoading ? null : _startGoogleOAuth,
            icon: _oauthLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: PortalColors.onGold,
                    ),
                  )
                : const Icon(Icons.add_link, size: 20),
            label: const Text('Conectar conta Google'),
            style: ElevatedButton.styleFrom(
              backgroundColor: PortalColors.gold,
              foregroundColor: PortalColors.onGold,
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (_connections.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 32),
              child: Column(
                children: [
                  const Icon(
                    Icons.mail_outline,
                    color: PortalColors.muted,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Nenhuma conexão de e-mail cadastrada.',
                    style: TextStyle(color: PortalColors.muted),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else ...[
          const Text(
            'Conexões ativas',
            style: TextStyle(
              color: PortalColors.gold,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ..._connections.map(_buildConnectionCard),
        ],
      ],
    );
  }

  Widget _buildConnectionCard(EmailConnection conn) {
    final healthColor = switch (conn.health.status) {
      'valid' => PortalColors.gold,
      'expired' => PortalColors.danger,
      'inactive' => PortalColors.muted,
      _ => PortalColors.muted,
    };

    final healthLabel = switch (conn.health.status) {
      'valid' => 'Válida',
      'expired' => 'Expirada',
      'inactive' => 'Inativa',
      _ => 'Indisponível',
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: PortalColors.darkWine,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: PortalColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
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
                    conn.provider.toUpperCase(),
                    style: const TextStyle(
                      color: PortalColors.gold,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: PortalColors.field,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: healthColor),
                  ),
                  child: Text(
                    healthLabel,
                    style: TextStyle(color: healthColor, fontSize: 11),
                  ),
                ),
                const Spacer(),
                Text(
                  'Prioridade: ${conn.priority}',
                  style: const TextStyle(
                    color: PortalColors.muted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              conn.email,
              style: const TextStyle(
                color: PortalColors.text,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              conn.health.message,
              style: const TextStyle(color: PortalColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_updatingPriorityId == conn.id)
                  const Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: PortalColors.gold,
                      ),
                    ),
                  ),
                TextButton.icon(
                  onPressed: _updatingPriorityId == conn.id
                      ? null
                      : () => _editPriority(conn),
                  icon: const Icon(
                    Icons.edit_outlined,
                    color: PortalColors.muted,
                    size: 16,
                  ),
                  label: const Text(
                    'Editar',
                    style: TextStyle(color: PortalColors.muted, fontSize: 13),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _deleteConnection(conn.id),
                  icon: const Icon(
                    Icons.delete_outline,
                    color: PortalColors.danger,
                    size: 16,
                  ),
                  label: const Text(
                    'Remover',
                    style: TextStyle(color: PortalColors.danger, fontSize: 13),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
