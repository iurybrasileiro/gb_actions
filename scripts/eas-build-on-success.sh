#!/usr/bin/env bash

if [ $GB_PR_NUMBER ]; then
   curl -Ls "https://get.maestro.mobile.dev" | bash
   export PATH="$PATH":"$HOME/.maestro/bin"

   if [ "$EAS_BUILD_PLATFORM" = "ios" ]; then
      bash ./scripts/pre-run-tests-ios.sh

      APP_EXECUTABLE_PATH=/Users/expo/workingdir/build/ios/build/Build/Products/Release-iphonesimulator/Fluyo.app
   else
      APP_EXECUTABLE_PATH=/home/expo/workingdir/build/android/app/build/outputs/apk/release/app-x86_64-release.apk
   fi

   MAESTRO_CLI_OUTPUT=$(maestro cloud -e APP_ID=com.fluyo --api-key=$MAESTRO_API_KEY --app-file=$APP_EXECUTABLE_PATH --flows=.maestro/)

   echo "$MAESTRO_CLI_OUTPUT"

   MAESTRO_HAS_ERROR=$(echo "$MAESTRO_CLI_OUTPUT" | grep -i "Failed" | head -1)
   MAESTRO_RESULT_URL=$(echo "$MAESTRO_CLI_OUTPUT" | grep -o 'http[s]*://[^"]*' | head -n 1)

   PLATFORM="$(echo $EAS_BUILD_PLATFORM | tr '[:lower:]' '[:upper:]')"

   if [ $MAESTRO_HAS_ERROR ]; then
      GB_MESSAGE="MAESTRO - $PLATFORM: FAILED ❌ $MAESTRO_RESULT_URL"
   else
      GB_MESSAGE="MAESTRO - $PLATFORM: PASSED ✅ $MAESTRO_RESULT_URL"
   fi

   curl -L \
      -X POST \
      -H "Authorization: Bearer $GITHUB_MAESTRO_PAT" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      https://api.github.com/repos/fluyoapp/mobile/issues/comments/${COMMENT_ID}/replies \
      --data-raw "{\"body\":\"$GB_MESSAGE\"}"

   # Check for both Android and iOS replies in the comment thread
   REPLIES_URL="https://api.github.com/repos/fluyoapp/mobile/issues/comments/${COMMENT_ID}/reactions"
   REPLIES=$(curl -s -H "Authorization: Bearer $GITHUB_MAESTRO_PAT" $REPLIES_URL)

   ANDROID_REPLY=$(echo "$REPLIES" | jq '.[] | select(.body | contains("ANDROID"))')
   IOS_REPLY=$(echo "$REPLIES" | jq '.[] | select(.body | contains("IOS"))')

   ANDROID_PASSED=$(echo "$ANDROID_REPLY" | grep -o "PASSED")
   IOS_PASSED=$(echo "$IOS_REPLY" | grep -o "PASSED")

   # If both Android and iOS replies are marked as PASSED, resolve the comment
   if [[ "$ANDROID_PASSED" == "PASSED" && "$IOS_PASSED" == "PASSED" ]]; then
      curl -L \
         -X PATCH \
         -H "Authorization: Bearer $GITHUB_MAESTRO_PAT" \
         -H "X-GitHub-Api-Version: 2022-11-28" \
         https://api.github.com/repos/fluyoapp/mobile/issues/comments/${COMMENT_ID} \
         --data-raw "{\"body\":\"All tests passed ✅. Resolving comment.\"}"
   fi

   set -e

   if [ $MAESTRO_HAS_ERROR ]; then
      exit 1
   fi
fi
