/// Validadores reutilizables para formularios de Aether.
/// Úsalos con TextFormField → validator: Validators.email
class Validators {
  Validators._(); // Evita instanciación accidental

  /// Email válido según RFC básico
  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'El email es obligatorio';
    }
    final regex = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w{2,}$');
    if (!regex.hasMatch(value.trim())) {
      return 'Ingresa un email válido';
    }
    return null;
  }

  /// Contraseña segura: mínimo 8 caracteres, 1 mayúscula, 1 número
  /// Solo para Login: Solo revisa que no esté vacío
  static String? loginPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'La contraseña es obligatoria';
    }
    return null;
  }

  /// Solo para Registro: Mantiene la seguridad (Mayúsculas, Números, etc.)
  static String? registerPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'La contraseña es obligatoria';
    }
    if (value.length < 8) {
      return 'Mínimo 8 caracteres';
    }
    if (!value.contains(RegExp(r'[A-Z]'))) {
      return 'Debe tener al menos una mayúscula';
    }
    if (!value.contains(RegExp(r'[0-9]'))) {
      return 'Debe tener al menos un número';
    }
    return null;
  }

  /// Confirmar que dos contraseñas coinciden
  static String? Function(String?) confirmPassword(String original) {
    return (String? value) {
      if (value == null || value.isEmpty) {
        return 'Confirma tu contraseña';
      }
      if (value != original) {
        return 'Las contraseñas no coinciden';
      }
      return null;
    };
  }

  /// Nombre de usuario: entre 3 y 20 caracteres, sin espacios
  static String? username(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'El nombre de usuario es obligatorio';
    }
    if (value.trim().length < 3) {
      return 'Mínimo 3 caracteres';
    }
    if (value.trim().length > 20) {
      return 'Máximo 20 caracteres';
    }
    if (value.contains(' ')) {
      return 'No puede contener espacios';
    }
    return null;
  }
}
