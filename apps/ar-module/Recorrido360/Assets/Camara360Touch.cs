using UnityEngine;
using UnityEngine.InputSystem; // ¡Esta es la llave para el nuevo sistema!

public class Camara360Touch : MonoBehaviour
{
    public float velocidadGiro = 0.2f; // Lo bajamos un poco porque el nuevo sistema es más sensible
    private float yaw = 0f;
    private float pitch = 0f;

    void Update()
    {
        // Revisamos si hay un apuntador activo (dedo o mouse) y si está presionando la pantalla
        if (Pointer.current != null && Pointer.current.press.isPressed)
        {
            // Leemos el movimiento exacto del dedo en la pantalla
            Vector2 movimiento = Pointer.current.delta.ReadValue();

            yaw += movimiento.x * velocidadGiro;
            pitch -= movimiento.y * velocidadGiro;
            
            // Limitamos para no mirar más allá del techo o del piso
            pitch = Mathf.Clamp(pitch, -90f, 90f);

            // Giramos la cámara
            transform.eulerAngles = new Vector3(pitch, yaw, 0f);
        }
    }
}