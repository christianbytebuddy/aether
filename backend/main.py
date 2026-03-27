from fastapi import FastAPI
import firebase_admin
from firebase_admin import credentials, firestore

# Inicializar Firebase
cred = credentials.Certificate("serviceAccountKey.json")
firebase_admin.initialize_app(cred)
db = firestore.client()

# Crear API
app = FastAPI()

# Ruta de prueba
@app.get("/")
def home():
    return {"mensaje": "API funcionando"}

# Crear nota
@app.post("/notas")
def crear_nota(titulo: str, contenido: str):
    doc_ref = db.collection("notas").add({
        "titulo": titulo,
        "contenido": contenido
    })
    return {"mensaje": "Nota guardada"}

# Obtener notas
@app.get("/notas")
def obtener_notas():
    docs = db.collection("notas").stream()
    resultado = []
    for doc in docs:
        data = doc.to_dict()
        data["id"] = doc.id
        resultado.append(data)
    return resultado