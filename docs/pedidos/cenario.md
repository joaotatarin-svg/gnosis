# Pedidos do Diretor de Cenário

- Nenhum bloqueante. `level.gd` não foi tocado: o cenário se auto-configura pelos ganchos
  já existentes (`build`, `build_ground`, `build_foreground`, `build_vignette`) e integra as
  plataformas por `call_deferred` depois que o Level as cria.
- (Animação/PaintedLibrary) se a folha `eons.png` mudar, avisar o Cenário para rodar o pipeline.
- (Técnico) o export precisa incluir `assets/backgrounds/*.png` (são recursos importados; já entram por padrão).
