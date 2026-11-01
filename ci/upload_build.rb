require "base64"
require "digest"
require "json"
require "net/http"
require "openssl"
require "uri"

API_ROOT = "https://api.appstoreconnect.apple.com"
KEY_ID = ENV.fetch("APP_STORE_CONNECT_KEY_ID")
ISSUER_ID = ENV.fetch("APP_STORE_CONNECT_ISSUER_ID")
APP_ID = ENV.fetch("APP_STORE_APP_ID")
KEY_PATH = ENV.fetch("API_KEY_PATH")
IPA_PATH = ENV.fetch("IPA_PATH")
MARKETING_VERSION = ENV.fetch("MARKETING_VERSION")
BUILD_VERSION = ENV.fetch("BUILD_VERSION")

def encode(value)
  Base64.urlsafe_encode64(value, padding: false)
end

def token
  key = OpenSSL::PKey.read(File.read(KEY_PATH))
  header = encode({ alg: "ES256", kid: KEY_ID, typ: "JWT" }.to_json)
  payload = encode({
    iss: ISSUER_ID,
    iat: Time.now.to_i - 30,
    exp: Time.now.to_i + 600,
    aud: "appstoreconnect-v1"
  }.to_json)
  signature = OpenSSL::ASN1.decode(
    key.sign(OpenSSL::Digest::SHA256.new, "#{header}.#{payload}")
  ).value.map { |integer| integer.value.to_s(16).rjust(64, "0") }.join
  "#{header}.#{payload}.#{encode([signature].pack("H*"))}"
end

def api_request(method, path, body = nil)
  uri = URI("#{API_ROOT}#{path}")
  request_class = { get: Net::HTTP::Get, post: Net::HTTP::Post, patch: Net::HTTP::Patch }.fetch(method)
  request = request_class.new(uri)
  request["Authorization"] = "Bearer #{token}"
  request["Content-Type"] = "application/json"
  request.body = JSON.generate(body) if body
  response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(request) }
  parsed = response.body.empty? ? {} : JSON.parse(response.body)
  return parsed if response.code.to_i.between?(200, 299)

  details = parsed.fetch("errors", []).map { |error| error["detail"] || error["title"] }.join("; ")
  abort("Apple API #{method.to_s.upcase} #{path} failed (#{response.code}): #{details}")
end

def upload_part(operation, file)
  uri = URI(operation.fetch("url"))
  request = Net::HTTP.const_get(operation.fetch("method").capitalize).new(uri)
  operation.fetch("requestHeaders", []).each do |header|
    request[header.fetch("name")] = header.fetch("value")
  end
  file.seek(operation.fetch("offset"))
  request.body = file.read(operation.fetch("length"))
  response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(request) }
  abort("Apple asset upload failed (#{response.code})") unless response.code.to_i.between?(200, 299)
end

file_size = File.size(IPA_PATH)
upload = api_request(:post, "/v1/buildUploads", {
  data: {
    type: "buildUploads",
    attributes: {
      cfBundleShortVersionString: MARKETING_VERSION,
      cfBundleVersion: BUILD_VERSION,
      platform: "IOS"
    },
    relationships: { app: { data: { type: "apps", id: APP_ID } } }
  }
})
upload_id = upload.fetch("data").fetch("id")
puts "Build upload reserved: #{upload_id}"

upload_file = api_request(:post, "/v1/buildUploadFiles", {
  data: {
    type: "buildUploadFiles",
    attributes: {
      assetType: "ASSET",
      fileName: File.basename(IPA_PATH),
      fileSize: file_size,
      uti: "com.apple.ipa"
    },
    relationships: { buildUpload: { data: { type: "buildUploads", id: upload_id } } }
  }
})
file_data = upload_file.fetch("data")
file_id = file_data.fetch("id")
operations = file_data.fetch("attributes").fetch("uploadOperations")
puts "Uploading #{file_size} bytes in #{operations.length} part(s)..."
File.open(IPA_PATH, "rb") do |file|
  operations.each_with_index do |operation, index|
    upload_part(operation, file)
    puts "Uploaded part #{index + 1}/#{operations.length}"
  end
end

checksum = Digest::MD5.file(IPA_PATH).hexdigest
api_request(:patch, "/v1/buildUploadFiles/#{file_id}", {
  data: {
    type: "buildUploadFiles",
    id: file_id,
    attributes: {
      sourceFileChecksums: { file: { algorithm: "MD5", hash: checksum } },
      uploaded: true
    }
  }
})
puts "Upload committed; Apple processing started."

60.times do
  status = api_request(:get, "/v1/buildUploads/#{upload_id}")
  state_value = status.fetch("data").fetch("attributes").fetch("state")
  state = state_value.is_a?(Hash) ? state_value.fetch("state") : state_value
  puts "Build upload state: #{state}"
  exit(state == "COMPLETE" ? 0 : 1) if %w[COMPLETE FAILED].include?(state)
  sleep 10
end

abort("Apple did not finish processing the upload within ten minutes.")
