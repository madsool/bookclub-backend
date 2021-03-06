require "./auth/auth.rb"
require "bcrypt"

class AuthTester
  include Auth
end

describe Auth do
  let(:auth_tester) { AuthTester.new }
  describe "verify_auth_input" do
    it "fails on empty username" do
      expect { auth_tester.verify_auth_input(nil, nil) }.to raise_error(BookclubErrors::AuthError, "Missing `username` in request")
      expect { auth_tester.verify_auth_input("", nil) }.to raise_error(BookclubErrors::AuthError, "Missing `username` in request")
    end
    it "fails on empty password" do
      expect { auth_tester.verify_auth_input("some_username", nil) }.to raise_error(BookclubErrors::AuthError, "Missing `password` in request")
      expect { auth_tester.verify_auth_input("some_username", "") }.to raise_error(BookclubErrors::AuthError, "Missing `password` in request")
    end
  end

  describe "verify_registration_input" do
    it "fails on empty email" do
      expect { auth_tester.verify_registration_input("some_username", "some_password", nil) }.to raise_error(BookclubErrors::AuthError, "Missing `email` in request")
      expect { auth_tester.verify_registration_input("some_username", "some_password", "") }.to raise_error(BookclubErrors::AuthError, "Missing `email` in request")
    end
  end

  describe "register_user" do
    it "fails on username that already exists" do
      expect_any_instance_of(Repository).to receive(:get_user_from_username).and_return({ "username": "some_username" })
      expect { auth_tester.register_user("some_username", "some_password", "some_email") }.to raise_error(BookclubErrors::AuthError, "User already exists")
    end
    it "creates a user in the db" do
      expect_any_instance_of(Repository).to receive(:get_user_from_username).and_return(nil)
      expect(auth_tester).to receive(:generate_token).and_return({
        user_id: "some_id",
        access_token: "some_token",
        expiry: "some_date",
      })
      expect_any_instance_of(Repository).to receive(:create_user).and_return("some_user_id")
      response = auth_tester.register_user("some_username", "some_password", "some_email")
      expect(response).to eq({
                            user_id: "some_id",
                            access_token: "some_token",
                            expiry: "some_date",
                            username: "some_username",
                          })
    end
  end

  describe "verify_user" do
    it "fails on missing username" do
      expect_any_instance_of(Repository).to receive(:get_user_from_username).and_return(nil)
      expect { auth_tester.verify_user("some_username", "some_password") }.to raise_error(BookclubErrors::AuthError, "User does not exist")
    end
    it "fails on incorrect password" do
      expect_any_instance_of(Repository).to receive(:get_user_from_username).and_return({ :hashed_password => BCrypt::Password.create("some_password") })
      expect { auth_tester.verify_user("some_username", "some_incorrect_password") }.to raise_error(BookclubErrors::AuthError, "Incorrect password")
    end
    it "Succeeds on correct password" do
      expect_any_instance_of(Repository).to receive(:get_user_from_username).and_return({ :hashed_password => BCrypt::Password.create("some_password") })
      expect(auth_tester).to receive(:generate_token).and_return({
        user_id: "some_id",
        access_token: "some_token",
        expiry: "some_date",
      })
      response = auth_tester.verify_user("some_username", "some_password")
      expect(response).to eq({
                            user_id: "some_id",
                            access_token: "some_token",
                            expiry: "some_date",
                            username: "some_username",
                          })
    end
  end

  describe "verify_token" do
    context "Missing/Nonexistent token" do
      it "fails on incorrect token" do
        expect_any_instance_of(Repository).to receive(:get_token).and_return(nil)
        expect { auth_tester.verify_token("some_username", "some_token") }.to raise_error(BookclubErrors::AuthError, "Invalid token/user_id combination")
      end
    end
    context "Found/Existent token" do
      it "fails on expired token" do
        expect_any_instance_of(Repository).to receive(:get_token).and_return({ expiry: Time.now - 1 })
        expect { auth_tester.verify_token("some_username", "some_token") }.to raise_error(BookclubErrors::AuthError, "Token expired")
      end
    end
  end
end
