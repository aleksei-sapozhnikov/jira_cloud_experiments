locals {
  jira_question_types = {
    short_text = "ts"
    long_text  = "tl"
    paragraph  = "rt"
    radio      = "cs"
    checkboxes = "cm"
    dropdown   = "cd"
    date       = "da"
    number     = "no"
    email      = "te"
    url        = "tu"
  }

  questions = {
    for question in var.form.questions :
    tostring(question.id) => merge(
      {
        type        = local.jira_question_types[question.type]
        label       = question.label
        questionKey = question.key
        validation = {
          rq = question.required
        }
        choices = [
          for choice_index, choice_label in question.choices : {
            id    = tostring(choice_index + 1)
            label = choice_label
            other = false
          }
        ]
      },
      question.description == null
      ? {}
      : { description = question.description }
    )
  }

  layout = [{
    version = 1
    type    = "doc"
    content = [
      for question in var.form.questions : {
        type = "extension"
        attrs = {
          extensionType = "com.thinktilt.proforma"
          extensionKey  = "question"
          parameters = {
            id = question.id
          }
          layout = "default"
          localId = uuidv5(
            "url",
            "jira-form://${var.project_key}/${var.form.name}/${question.id}"
          )
        }
      }
    ]
  }]

  payload = {
    design = {
      conditions = {}
      layout     = local.layout
      questions  = local.questions
      sections   = {}
      settings = {
        language      = var.form.language
        name          = var.form.name
        primaryLocale = var.form.primary_locale
        submit = {
          lock = var.form.submit.lock
          pdf  = var.form.submit.pdf
        }
      }
    }
    publish = merge(
      {
        jira = {
          issueCreateIssueTypeIds = [
            var.publication.issue_type_id
          ]
          issueCreateRequestTypeIds      = []
          recommendedIssueRequestTypeIds = []
          submitOnCreate                 = var.publication.submit_on_create
          validateOnCreate               = var.publication.validate_on_create
        }
      },
      var.publication.portal
      ? {
        portal = {
          portalRequestTypeIds = [
            var.publication.request_type_id
          ]
          submitOnCreate   = var.publication.submit_on_create
          validateOnCreate = var.publication.validate_on_create
        }
      }
      : {}
    )
  }
}

resource "terraform_data" "form_owner" {
  input = var.project_key
}

resource "restapi_object" "form" {
  path         = "/project/${var.project_key}/form"
  id_attribute = "id"
  data         = jsonencode(local.payload)

  ignore_server_additions = true

  lifecycle {
    replace_triggered_by = [
      terraform_data.form_owner
    ]

    precondition {
      condition = (
        length(trimspace(var.publication.issue_type_id)) > 0
      )
      error_message = "The publication work type \"${var.publication.issue_type_name}\" was not found in Jira space \"${var.project_key}\". Create work type \"${var.publication.issue_type_name}\" in space \"${var.project_key}\", or correct publish.issue_type in forms.json."
    }

    precondition {
      condition = (
        length(trimspace(var.publication.request_type_id)) > 0
      )
      error_message = "The publication request type \"${var.publication.request_type_name}\" was not found in Jira service space \"${var.project_key}\". Create request type \"${var.publication.request_type_name}\" in space \"${var.project_key}\", or correct publish.request_type in forms.json."
    }
  }
}
