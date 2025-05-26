Deploy the vLLM Inference Engine to Run Large Language Models (LLM) on Koyeb
Introduction
vLLM is a high performance and easy-to-use library for running inference workloads. It allows you to download popular models from Hugging Face, run them on local hardware with custom configuration, and serve an OpenAI-compatible API server as an interface. Using vLLM, you can experiment with different models and build LLM-based applications without relying on externally hosted services.

In this tutorial, we will show you how to set up a vLLM instance running on GPUs on Koyeb. We will create a custom Dockerfile to simplify configuration. Afterwards, we will deploy vLLM to Koyeb's GPU instances and demonstrate how to interact with the completions and chat APIs. Finally, we'll discuss some additional customization options that you can use to extend your vLLM instance.

You can consult the repository for this guide to follow along on your own. You can deploy the vLLM instance by clicking the Deploy to Koyeb button below:

Deploy to Koyeb

Be sure to set the HF_TOKEN environment variable to a Hugging Face read-only API token value so vLLM can authenticate correctly. You will also need to set the Grace period in the Health checks section to 300 seconds. You can consult the appropriate sections of this guide for additional information.

Requirements
To successfully follow and complete this guide, you need:

A Koyeb account to build and run the vLLM instance on GPUs.
Access to GPU Instances on Koyeb. Join the preview today to gain access.
Hugging Face account with a read-only API token. You will use this to fetch the models that vLLM will run. You may also need to accept the terms and conditions or usage license agreements associated with the models you intend to use. In some cases, you may need to request access to the model from the model owners on Hugging Face. For this guide, make sure you have accepted any terms required for the google/gemma-2b-it model.
Steps
To complete this guide and deploy your own vLLM instance, you'll need to follow these steps:

Create a custom Dockerfile
Push the Dockerfile to GitHub
Deploy vLLM on Koyeb
Querying the model with the vLLM API
Querying the completions endpoint
Querying the chat endpoint
Additional vLLM image customization
Create a custom Dockerfile
The simplest way to deploy vLLM on Koyeb is to use the project-provided Docker image. This image is mainly configured by passing command arguments at runtime.

While this works as intended, it can be awkward to use in practice when longer argument lists are necessary. As an alternative, we can build a Dockerfile based on the official image that takes its configuration from environment variables. Koyeb can build a container image from the Dockerfile during deployment.

Begin by creating a new project directory on your local computer and navigating inside:

mkdir example-vllm
cd example-vllm
Once inside, create a Dockerfile with the following content:

FROM vllm/vllm-openai:latest

ENTRYPOINT python3 -m vllm.entrypoints.openai.api_server \
 --port ${PORT:-8000} \
    --model ${MODEL_NAME:-google/gemma-2b-it} \
    ${REVISION:+--revision "$REVISION"}
This uses the latest version of the vllm/vllm-openai image as its starting point. It sets a new ENTRYPOINT instruction that mirrors the one from the base image, with a few key differences:

Instead of using the exec form, it uses the shell form so that environment variables can be evaluated.
It appends command arguments that we may wish to configure at runtime to the end.
The command parameters use parameter expansion to provide default values and to only include configuration flags when their associate environment variables are present.

Using this Dockerfile, we can build an image that we can configure by passing the PORT, MODEL_NAME, and REVISION environment variables at runtime.

Push the Dockerfile to GitHub
The Dockerfile above is the only thing we need to build an easily configurable vLLM image. We can commit the file to a git repository and push it to GitHub.

Create a new GitHub repository and then run the following commands to commit and push changes to your GitHub repository:

git add :/
git commit -m "Initial commit"
git remote add origin git@github.com:<YOUR_GITHUB_USERNAME>/<YOUR_REPOSITORY_NAME>.git
git branch -M main
git push -u origin main
Note: Make sure to replace <YOUR_GITHUB_USERNAME> and <YOUR_REPOSITORY_NAME> with your GitHub username and repository name.

Deploy vLLM on Koyeb
Now that the Dockerfile is on GitHub, we can deploy it to Koyeb. On the Overview tab of the Koyeb control panel, click Create Web Service to begin:

Select GitHub as the deployment method.

Select your vLLM project repository. Alternatively, you can enter our public vLLM example repository into the Public GitHub repository field at the bottom of the page: https://github.com/koyeb/example-vllm.

In the Environment variables and files section, click Bulk edit to enter multiple environment variables at once. In the text box that appears, paste the following:

HF_TOKEN=
MODEL_NAME=
REVISION=
VLLM_API_KEY=
Set the variable values to reference your own information as follows:

HF_TOKEN: Set this to your Hugging Face read-only API token.
MODEL_NAME: Set this to the name of the model you wish to use, as given on the Hugging Face site. You can check what models vLLM supports to find out more. Click the model name copy icon on the Hugging Face page to copy the appropriate value. Remove this variable to deploy the default google/gemma-2b-it model.
REVISION: Set this to the model revision you wish to use. You can find available revisions in a drop down menu on the Files and versions tab of the Hugging Face model page. Remove this variable to deploy the default revision.
VLLM_API_KEY: This defines an authorization token that must be provided when querying the API. Remove this if you wish to allow unauthenticated queries to your API.
In the Instance section, select the GPU category and choose RTX-4000-SFF-ADA. These Instances are available when you request access to the GPU preview.

In the Health checks section, set the Grace period to 300 seconds. This will provide time for vLLM to download the appropriate model from Hugging face and initialize the server.

Click Deploy.

Koyeb will pull your vLLM repository, build the Dockerfile it contains, and run it on a GPU Instance. During deployment, vLLM will fetch the provided model from Hugging Face and start up the API server to expose it to users.

Once the deployment is complete, access your vLLM instance by visiting your Koyeb deployment URL. The application URL should have the following format:

https://<YOUR_APP_NAME>-<YOUR_KOYEB_ORG>-<HASH>.koyeb.app
If you did not include the VLLM_API_KEY variable during deployment, you should be able to access the API interface using your web browser (we will demonstrate how to authenticate with an API key in the next section). To verify the model was loaded as expected, visit the /v1/models path:

{
"object": "list",
"data": [
{
"id": "google/gemma-2b-it",
"object": "model",
"created": 1718289027,
"owned_by": "vllm",
"root": "google/gemma-2b-it",
"parent": null,
"max_model_len": 8192,
"permission": [
{
"id": "modelperm-5b9bc16d74f94d71aa5c5a6de4a49078",
"object": "model_permission",
"created": 1718289027,
"allow_create_engine": false,
"allow_sampling": true,
"allow_logprobs": true,
"allow_search_indices": false,
"allow_view": true,
"allow_fine_tuning": false,
"organization": "*",
"group": null,
"is_blocking": false
}
]
}
]
}
Querying the model with the vLLM API
While you can access the API's web interface in a browser, you cannot pass information required to interact meaningfully with the API. To do so, you need to use a more configurable HTTP client. In the examples below, we'll use curl and jq as a basic toolkit.

We can replicate the model query shown above by typing:

curl <YOUR_VLLM_API_URL>/v1/models -H "Content-Type: application/json" | jq
If you configured an API key with VLLM_API_KEY, you must include the token in an authentication header like this:

curl <YOUR_VLLM_API_URL>/v1/models -H "Content-Type: application/json" \
 -H "Authorization: Bearer <YOUR_VLLM_API_KEY>" | jq
In the rest of the examples, we will include the Authorization header, but you can delete that if your deployment does not require it.

Querying the completions endpoint
To use the completions API, query the /v1/completions endpoint, passing in a JSON object that sets the model, prompt, max_tokens, and temperature:

curl <YOUR_VLLM_API_URL>/v1/completions -H "Content-Type: application/json" \
 -H "Authorization: Bearer <YOUR_VLLM_API_KEY>" \
 -d '{
"model": "google/gemma-2b-it",
"prompt": "An avocado is a",
"max_tokens": 30,
"temperature": 0
}' | jq
The response object includes a choices.text field with the response:

{
"id": "cmpl-006ef2ad91c54182af85736b6f50d2f5",
"object": "text_completion",
"created": 1718286831,
"model": "google/gemma-2b-it",
"choices": [
{
"index": 0,
"text": " fruit, but it is not a berry. It is a seedless fruit that is high in monounsaturated fat. Avocados are often used in",
"logprobs": null,
"finish_reason": "length",
"stop_reason": null
}
],
"usage": {
"prompt_tokens": 5,
"total_tokens": 35,
"completion_tokens": 30
}
}
Querying the chat endpoint
The google/gemma-2b-it model includes a chat template that allows you to query in a conversational manner using roles.

Use the chat endpoint by querying /v1/chat/completions. Instead of passing a prompt, this time, the request object must include a messages array that defines a user role with a query:

curl <YOUR_VLLM_API_URL>/v1/chat/completions -H "Content-Type: application/json" \
 -H "Authorization: Bearer <YOUR_VLLM_API_KEY>" \
 -d '{
"model": "google/gemma-2b-it",
"messages": [{"role": "user", "content": "Why is the sky blue?"}]
}' | jq
The response object will include a response associated with the "assistant" role defined by the chat template:

{
"id": "cmpl-90c4a7b4f3664aa7ab46c78aed05346e",
"object": "chat.completion",
"created": 1718289767,
"model": "google/gemma-2b-it",
"choices": [
{
"index": 0,
"message": {
"role": "assistant",
"content": "The sky is blue due to Rayleigh scattering. Rayleigh scattering is the scattering of light by particles that have a size comparable to the wavelength of light. The blue light has a longer wavelength than other colors of light, so it is scattered more strongly. This is why the sky appears blue.",
"tool_calls": []
},
"logprobs": null,
"finish_reason": "stop",
"stop_reason": null
}
],
"usage": {
"prompt_tokens": 15,
"total_tokens": 73,
"completion_tokens": 58
}
}
Additional vLLM image customization
The Dockerfile we created earlier includes a basic amount of configurability with a few of the most common options you might want to change. If you need to customize the image and functionality further, you can continue to develop the Dockerfile.

If you need to configure additional vLLM options for your deployment, you can extend the Dockerfile with additional parameters based on the presence or absence of environment variables.

To include most of the vLLM options, you can deploy an image that can respond to a large number of variables:

Note: Expand here to see fully parameterized Dockerfile.

The image built from this Dockerfile will be able to respond to most of the configuration options for vLLM by setting environment variables. Any environment variables not provided will use the vLLM default values.

You can also include other files in your vLLM repository that your image can use. One example of this is providing chat templates that your model can use.

For example, assuming you have created a template in the root of your vLLM repository at chat-template.jinja, you could use a Dockerfile like this:

FROM vllm/vllm-openai:latest

COPY chat-template.jinja .

ENTRYPOINT python3 -m vllm.entrypoints.openai.api_server \
 --port ${PORT:-8000} \
    --model ${MODEL_NAME:-google/gemma-2b-it} \
    ${CHAT_TEMPLATE:+--chat-template "$CHAT_TEMPLATE"} \
 ${REVISION:+--revision "$REVISION"}
During deployment, you would set CHAT_TEMPLATE to ./chat-template.jinja to use your custom template instead of a default template included in your model.

Conclusion
In this guide, we discussed how to deploy and customize a vLLM Instance on Koyeb to run AI workloads. We started with the basic vLLM Docker image and redefined the ENTRYPOINT to make it simpler to configure during deployment.

Afterwards, we deployed vLLM to Koyeb by building the Dockerfile and launching it on Koyeb's GPU Instances. The container image downloads the provided model at runtime and starts up an OpenAI-compatible API server. We showed how to query the models loaded on the server and how to use both the /v1/completions and /v1/chat/completions endpoints to interact with the model. Finally, we discussed further customization options you might wish to pursue to construct your ideal AI server.
