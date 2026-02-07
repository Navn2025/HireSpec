import os
from twilio.rest import Client

# Load from environment variables - NEVER commit secrets to git
ACCOUNT_SID = os.getenv("TWILIO_ACCOUNT_SID")
AUTH_TOKEN = os.getenv("TWILIO_AUTH_TOKEN")

if not ACCOUNT_SID or not AUTH_TOKEN:
    raise ValueError("Set TWILIO_ACCOUNT_SID and TWILIO_AUTH_TOKEN environment variables")

client = Client(ACCOUNT_SID, AUTH_TOKEN)

call = client.calls.create(
    to="+917879236797",                  # your verified Indian number
    from_="+17655076955",               # your Twilio number
    url="https://garnet-reedier-jolene.ngrok-free.dev/answer"
)

print("Call SID:", call.sid)
