extends RefCounted
class_name PaintedLibrary
## Catálogo único: regiões, pivôs e materiais das ilustrações do jogo.
static var textures: Dictionary = {}
static var regions: Dictionary = {}
static var shared_material: ShaderMaterial

static func sheet(file: String) -> Texture2D:
	if not textures.has(file):
		textures[file] = load("res://assets/painted/" + file + ".png")
	return textures[file]

static func material() -> ShaderMaterial:
	if shared_material == null:
		shared_material = ShaderMaterial.new()
		shared_material.shader = load("res://assets/shaders/painted_key.gdshader")
	return shared_material

static func region(file: String, rect: Rect2) -> AtlasTexture:
	var key: String = file + str(rect)
	if not regions.has(key):
		var tex := AtlasTexture.new()
		tex.atlas = sheet(file)
		tex.region = rect
		tex.filter_clip = true
		regions[key] = tex
	return regions[key]

static func character(p: ArtProfile) -> Dictionary:
	if p.has("hero"):
		return {"sheet": "sophia", "hero": true, "flip": false}
	var id: String = p.painted_id.trim_prefix("eco_")
	if p.has("soter"): id = "soter"
	if p.has("velkar"): id = "velkar"
	# Variantes do Éon herdam a família do seu Arconte, em escala de criatura.
	var families := {"sonambulo":"arconte_sono","glutao":"arconte_fome","carcereiro":"arconte_corrente","mudo":"arconte_silencio","reflexo":"arconte_espelho","esporos":"arconte_praga","pretoriano":"arconte_coroa","alado":"arconte_silencio","fantasma":"arconte_sono","cornudo":"arconte_corrente"}
	id = families.get(id,id)
	var bosses := ["arconte_sono", "arconte_fome", "arconte_corrente", "arconte_silencio", "arconte_espelho", "arconte_praga", "arconte_coroa", "colosso"]
	var boss: int = bosses.find(id)
	if boss >= 0:
		var rects := [Rect2(0,0,379,505),Rect2(379,0,408,503),Rect2(787,0,380,516),Rect2(1167,0,369,507),Rect2(0,506,373,518),Rect2(373,523,427,473),Rect2(800,510,367,514),Rect2(1167,507,369,517)]
		return {"sheet":"archons", "rect":rects[boss], "flip":true}
	if id in ["rei", "rei_final", "demiurgo"]:
		return {"sheet":"yaldabaoth", "rect":Rect2(15,0,1046,1024), "flip":false}
	var index: int = 1
	if p.body == ArtProfile.Body.WRAITH: index = 0
	elif p.body in [ArtProfile.Body.BRUTE,ArtProfile.Body.COLOSSUS]: index = 2
	elif p.body == ArtProfile.Body.BEAST: index = 3
	if p.has("shield") or id in ["escudeiro", "carcereiro", "pretoriano"]: index = 4
	if p.has("staff") or id in ["invocador", "arauto", "mudo"]: index = 5
	if id == "soter": index = 6
	if id == "velkar": index = 7
	if id == "sleeper": index = 8
	var rects := [Rect2(0,0,425,400),Rect2(425,0,425,400),Rect2(850,0,397,400),Rect2(0,406,425,380),Rect2(425,406,425,380),Rect2(850,406,397,380),Rect2(0,786,425,475),Rect2(425,790,425,471),Rect2(850,790,397,471)]
	return {"sheet":"inhabitants", "rect":rects[index], "flip":false}

static func prop(index: int) -> Texture2D:
	var rects := [Rect2(85,0,325,545),Rect2(575,205,360,305),Rect2(1120,5,280,540),Rect2(5,564,530,409),Rect2(605,550,270,410),Rect2(928,720,598,195)]
	return region("architecture",rects[index])

static func sprite(index: int, height: float) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = prop(index)
	s.material = material()
	s.scale = Vector2.ONE * height / s.texture.get_height()
	s.offset.y = -s.texture.get_height() * 0.5
	return s

static func background(eon: int) -> Texture2D:
	var rows := [0.0,341.0,660.0,1024.0]
	var row: int = clampi(eon,0,8) / 3
	return region("eons",Rect2((eon%3)*512,rows[row],512,rows[row+1]-rows[row]))
