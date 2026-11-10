using System;

namespace TouristMAR.AR
{
    // Para cuando pides un solo lugar por su ID
    [Serializable]
    public class RespuestaLugarAPI
    {
        public DatosLugarRA lugar;
    }

    // NUEVO: Para cuando la API descarga la lista de todos los lugares
    [Serializable]
    public class ListaLugaresAPI
    {
        public DatosLugarRA[] lugares;
    }

    [Serializable]
    public class DatosLugarRA
    {
        public string id;
        public string nombre;
        public string categoria;
        public string textoParaMostrar;
        public string resumen;   // NUEVO: descripción corta del lugar
        public string detalle;   // NUEVO: información detallada del lugar
        public string direccion;
        public string urlPortada;
        public double latitud;
        public double longitud;
        public PuntoRA[] puntos;
        public float radioMetros;
        public bool tieneMarcadores;
    }

    [Serializable]
    public class PuntoRA
    {
        public string id;
        public string titulo;
        public string resumen;
        public string detalle;
        public string urlImagen;
        public string urlAudio;
        public double latitud;
        public double longitud;
        public float radioVisible;
        public float radioCercano;
    }
}