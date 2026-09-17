extends Resource
class_name ArtProfile
## "Receita" visual de um personagem. O CharacterArt desenha a partir disso.
## Perfil compartilhado entre a arte ilustrada ativa e o fallback procedural.

enum Body { HUMANOID, BRUTE, WRAITH, BEAST, COLOSSUS }

@export var body: Body = Body.HUMANOID
@export var height: float = 44.0                     # altura aprox. em px
@export var primary: Color = Color(0.82, 0.3, 0.28)  # cor do corpo
@export var secondary: Color = Color(0.18, 0.16, 0.22) # gear / detalhe
@export var eye: Color = Color(1.0, 0.86, 0.4)       # olho/faísca (brilho)
@export var skin: Color = Color(0.96, 0.9, 0.86)     # rosto (só quem tem "hero"/"face")
@export var hair: Color = Color(0.92, 0.86, 0.98)    # cabelo (feature "hair")
## Peças/adereços: "horns","crown","cape","wings","spikes","helmet",
## "pauldrons","bracers","blade","staff","claws","tail","aura","hero","shield",
## "hair","face","hood","tatters" + assinaturas dos Arcontes (eyelid, maw,
## chains, sewn, mirror, rot, bigcrown) + "cracked" (cacos da face do Rei).
@export var painted_id: String = ""
@export var features: PackedStringArray = []


func has(feature: String) -> bool:
	return features.has(feature)


func duplicate_with(extra: Array) -> ArtProfile:
	var p: ArtProfile = duplicate()
	for f in extra:
		if not p.features.has(f):
			p.features.append(f)
	return p
