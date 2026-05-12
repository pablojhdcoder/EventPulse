defmodule EventPulse.Accounts.AuthTest do
  # async: true permite ejecutar este test en paralelo con otros para ganar velocidad.
  use EventPulse.DataCase, async: true

  alias EventPulse.Accounts.Auth
  alias EventPulse.Accounts.User

 #Función helper para generar atributos válidos de usuario en los tests y no andar repitiendo
  defp valid_attrs do
    %{
      "username" => "testuser",
      "email" => "test@example.com",
      "password" => "Password1!",
      "role" => "participant"
    }
  end

#Registro de usuario

  describe "register/1" do
    test "registra un usuario con datos válidos" do
      assert {:ok, user} = Auth.register(valid_attrs())
      assert user.username == "testuser"
      assert user.email == "test@example.com"
      assert user.role == "participant"
    end

    test "no guarda la contraseña en texto plano" do
      assert {:ok, user} = Auth.register(valid_attrs())
      assert user.password_hash != "Password1!"
      assert user.password_hash != nil
    end

    test "falla si el email ya existe" do
      Auth.register(valid_attrs())
      assert {:error, changeset} = Auth.register(valid_attrs())
      assert %{email: ["has already been taken"]} = errors_on(changeset)
    end

    test "falla si el username ya existe" do
      Auth.register(valid_attrs())
      attrs = Map.put(valid_attrs(), "email", "otro@example.com")
      assert {:error, changeset} = Auth.register(attrs)
      assert %{username: ["has already been taken"]} = errors_on(changeset)
    end

    test "falla si el email no tiene formato válido" do
      attrs = Map.put(valid_attrs(), "email", "emailinvalido")
      assert {:error, changeset} = Auth.register(attrs)
      assert %{email: _} = errors_on(changeset)
    end

    test "falla si la contraseña es demasiado corta" do
      attrs = Map.put(valid_attrs(), "password", "Aa1!")
      assert {:error, changeset} = Auth.register(attrs)
      assert %{password: _} = errors_on(changeset)
    end

    test "falla si faltan campos obligatorios" do
      assert {:error, changeset} = Auth.register(%{})
      assert %{username: _, email: _, password: _} = errors_on(changeset)
    end
  end

  #Login de usuario
  describe "login/2" do
    setup do
      {:ok, user} = Auth.register(valid_attrs())
      %{user: user}
    end

    test "login correcto con credenciales válidas", %{user: user} do
      assert {:ok, logged_user} = Auth.login(user.email, "Password1!")
      assert logged_user.id == user.id
    end

    test "falla con contraseña incorrecta", %{user: user} do
      assert {:error, :invalid_credentials} = Auth.login(user.email, "wrongpassword")
    end

    test "falla con email que no existe" do
      assert {:error, :invalid_credentials} = Auth.login("noexiste@example.com", "Password1!")
    end
  end

 #Buscar usuario
  describe "get_user/1" do
    test "devuelve el usuario si existe" do
      {:ok, user} = Auth.register(valid_attrs())
      assert found = Auth.get_user(user.id)
      assert found.id == user.id
    end

    test "devuelve nil si el usuario no existe" do
      assert nil == Auth.get_user("00000000-0000-0000-0000-000000000000")
    end
  end

  describe "get_user_by_email/1" do
    test "devuelve el usuario si existe" do
      {:ok, user} = Auth.register(valid_attrs())
      assert found = Auth.get_user_by_email(user.email)
      assert found.id == user.id
    end

    test "devuelve nil si el email no existe" do
      assert nil == Auth.get_user_by_email("noexiste@example.com")
    end
  end

  describe "role helpers" do
    test "admin?/1 devuelve true solo para admin" do
      {:ok, user} = Auth.register(valid_attrs())
      assert not Auth.admin?(user)

      {:ok, admin} = Auth.register(%{
        "username" => "adminuser",
        "email" => "admin@example.com",
        "password" => "Password1!",
        "role" => "admin"
      })

      assert Auth.admin?(admin)
      assert Auth.can_create_event?(admin)
    end

    test "participant?/1 y can_create_event?/1 funcionan para participante" do
      {:ok, user} = Auth.register(valid_attrs())
      assert Auth.participant?(user)
      assert Auth.can_create_event?(user)
    end
  end

  #Actualizar datos de usuario
  describe "update_user/2" do
    setup do
      {:ok, user} = Auth.register(valid_attrs())
      %{user: user}
    end

    test "actualiza email y username correctamente", %{user: user} do
      assert {:ok, updated} = Auth.update_user(user, %{
        "username" => "newusername",
        "email" => "new@example.com"
      })
      assert updated.username == "newusername"
      assert updated.email == "new@example.com"
    end

    test "falla si el email nuevo ya está en uso", %{user: user} do
      {:ok, _other} = Auth.register(%{
        "username" => "otrouser",
        "email" => "otro@example.com",
        "password" => "Password1!",
        "role" => "participant"
      })
      assert {:error, changeset} = Auth.update_user(user, %{
        "username" => "testuser",
        "email" => "otro@example.com"
      })
      assert %{email: ["has already been taken"]} = errors_on(changeset)
    end
  end

  # ---------------------------------------------------------------------------
  # Cambiar contraseña
  # ---------------------------------------------------------------------------

  describe "update_password/2" do
    setup do
      {:ok, user} = Auth.register(valid_attrs())
      %{user: user}
    end

    test "cambia la contraseña correctamente", %{user: user} do
      assert {:ok, updated} = Auth.update_password(user, %{"password" => "NewPass1!"})
      assert {:ok, _} = Auth.login(user.email, "NewPass1!")
    end

    test "falla si la contraseña nueva es demasiado corta", %{user: user} do
      assert {:error, changeset} = Auth.update_password(user, %{"password" => "Aa1!"})
      assert %{password: _} = errors_on(changeset)
    end
  end

  #Borrar usuario
  describe "delete_user/1" do
    test "borra el usuario correctamente" do
      {:ok, user} = Auth.register(valid_attrs())
      assert {:ok, _} = Auth.delete_user(user)
      assert nil == Auth.get_user(user.id)
    end
  end
end
