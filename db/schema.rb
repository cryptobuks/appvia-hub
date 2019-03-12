# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2019_03_06_153823) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "pgcrypto"
  enable_extension "plpgsql"

  create_table "apps", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_apps_on_slug", unique: true
  end

  create_table "audits", force: :cascade do |t|
    t.string "auditable_type"
    t.uuid "auditable_id"
    t.string "auditable_descriptor"
    t.string "associated_type"
    t.uuid "associated_id"
    t.string "associated_descriptor"
    t.string "user_type"
    t.uuid "user_id"
    t.string "username"
    t.string "user_email"
    t.string "action"
    t.jsonb "audited_changes"
    t.integer "version", default: 0
    t.string "comment"
    t.string "remote_address"
    t.string "request_uuid"
    t.datetime "created_at", null: false
    t.string "auditable_model_name"
    t.index ["associated_type", "associated_id"], name: "index_audits_on_associated_type_and_associated_id"
    t.index ["auditable_type", "auditable_id"], name: "index_audits_on_auditable_type_and_auditable_id"
    t.index ["created_at"], name: "index_audits_on_created_at"
    t.index ["request_uuid"], name: "index_audits_on_request_uuid"
    t.index ["user_email"], name: "index_audits_on_user_email"
    t.index ["user_type", "user_id"], name: "index_audits_on_user_type_and_user_id"
  end

  create_table "configured_providers", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.string "kind", null: false
    t.text "config", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "resources", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "type", null: false
    t.uuid "app_id", null: false
    t.uuid "provider_id", null: false
    t.string "status", null: false
    t.string "name", null: false
    t.jsonb "metadata", default: {}, null: false
    t.string "lock_version"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["app_id"], name: "index_resources_on_app_id"
    t.index ["name", "provider_id"], name: "index_resources_on_name_and_provider_id", unique: true
    t.index ["provider_id"], name: "index_resources_on_provider_id"
    t.index ["type"], name: "index_resources_on_type"
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "email", null: false
    t.string "name"
    t.datetime "last_seen_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "resources", "apps"
  add_foreign_key "resources", "configured_providers", column: "provider_id"
end
