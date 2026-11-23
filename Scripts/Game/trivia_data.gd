class_name TriviaData
extends RefCounted
## Banco de preguntas. Se usa el MISMO banco antes y despues de jugar
## para comparar cuanto aprendio el jugador.
## "correct" = indice (empezando en 0) de la opcion correcta dentro de "options".

const QUESTIONS: Array = [
	{
		"question": "Tras un sismo, un edificio queda con etiqueta ROJA. ¿Qué significa?",
		"options": [
			"Hay que demolerlo de inmediato",
			"Es inseguro: no se ocupa y se estudia con más detalle",
			"Es seguro y se puede habitar",
			"Solo necesita pintura",
		],
		"correct": 1,
		"explanation": "Rojo = inseguro. No implica demolición automática: se hacen estudios más detallados.",
	},
	{
		"question": "Antes de intervenir una estructura dañada, ¿qué es lo primero?",
		"options": [
			"Retirar escombros lo más rápido posible",
			"Probar con maquinaria pesada",
			"Una evaluación técnica hecha por profesionales",
			"Esperar a que se caiga sola",
		],
		"correct": 2,
		"explanation": "Primero se evalúa el riesgo. Actuar sin planificar puede causar nuevos accidentes.",
	},
	{
		"question": "En Colombia, ¿qué autoriza derribar total o parcialmente una edificación?",
		"options": [
			"El permiso verbal de un vecino",
			"La licencia de construcción en modalidad de demolición",
			"No se necesita ningún permiso",
			"Un permiso de parqueo",
		],
		"correct": 1,
		"explanation": "Lo define el Decreto 1077 de 2015 (con excepciones, como órdenes judiciales o administrativas).",
	},
	{
		"question": "Para un edificio alto en una zona urbana apretada, ¿qué se suele preferir?",
		"options": [
			"Derribarlo de golpe sin avisar",
			"Demolición mecánica por pisos, de arriba hacia abajo",
			"Que cada vecino lo desarme",
			"Dejarlo abandonado",
		],
		"correct": 1,
		"explanation": "En espacios confinados suele ser más controlada. La implosión exige espacio, tiempo y especialistas autorizados.",
	},
	{
		"question": "¿Qué método es más común para una casa de 1 o 2 pisos?",
		"options": [
			"Excavadora y desmonte por partes",
			"Implosión con explosivos",
			"Una torre de grúas gigante",
			"Quemarla",
		],
		"correct": 0,
		"explanation": "En edificaciones bajas se usa maquinaria convencional y desmonte selectivo, siempre con perímetro de seguridad.",
	},
	{
		"question": "¿Qué principio es clave en cualquier demolición?",
		"options": [
			"Trabajar rápido aunque haya gente cerca",
			"Quitar las señales para no asustar",
			"Cada quien elige su ruta",
			"Mantener a las personas lejos del peligro con zonas de exclusión",
		],
		"correct": 3,
		"explanation": "La buena práctica separa a las personas de los peligros: perímetro, señalización y control de acceso.",
	},
]
