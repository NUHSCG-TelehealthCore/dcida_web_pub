'use strict'

module = angular.module('dcida20App')

class DecisionAidPropertiesCtrl
  @$inject: ['$scope', '$document', 'Confirm', '$timeout', '$state', '$stateParams', 'DecisionAidHome', 'DecisionAidUserProperty', 'moment', 'Auth', '_', 'NavBroadcastService', 'themeConfig', 'StateChangeRequested']
  constructor: (@$scope, @$document, @Confirm, @$timeout, @$state, @$stateParams, @DecisionAidHome, @DecisionAidUserProperty, @moment, @Auth, @_, @NavBroadcastService, @themeConfig, @StateChangeRequested) ->
    @$scope.ctrl = @

    @$scope.$on 'decisionAidInvalid', () =>
      @invalidDecisionAid()
      
    @loading = true
    @NavBroadcastService.emitLoadingToRoot(true, @$scope)
    @StateChangeRequested.subscribeToStateChange(@$scope)

    @$scope.$watch "ctrl.checkPropertiesLength()", (new_val, old_val) =>
      if @hasScrolled? and @hasScrolled is false
        if new_val >= @decisionAid.minimum_property_count
          @Confirm.alert(
            message: "Done!"
            messageSub: "Please scroll down. Move the sliders to show how important each factor is to you."
            headerClass: "text-success"
            buttonType: "default"
          )
          @hasScrolled = true
          # @$timeout () =>
          #   element = angular.element(document.getElementById('relative-importance-charts'))
          #   @$document.scrollTo element, 0, 1000
          #   @hasScrolled = true
          # , 500

    @colors = @themeConfig["COLORS"]

    @decisionAidSlug = @$stateParams.slug
    @decisionAid = null

    @DecisionAidHome.properties(@decisionAidSlug).then ((data) =>
      @decisionAid = data.decision_aid
      @decisionAidUser = data.meta.decision_aid_user
      @properties = data.decision_aid.properties
      #@maxSliderValue = (if @decisionAid.advanced_properties then 100 else 10)
      @step = (if @decisionAid.advanced_properties then 1 else 10)

      @DecisionAidUserProperty.query {decision_aid_user_id: @decisionAidUser.id}, (decisionAidUserProperties) =>
        @propertiesHash = @_.indexBy(decisionAidUserProperties, 'property_id')
        @hasScrolled = if @checkPropertiesLength() >= @decisionAid.minimum_property_count then true else false
        @orderedProperties = @orderedUserProperties()
        @Auth.decisionAidFound(@decisionAid, data.meta.pages, @decisionAidUser)
        @$scope.$emit 'dcida.percentageCompletedUpdate', {checkNextPage: true}
        @NavBroadcastService.emitLoadingToRoot(false, @$scope)

      , (error) =>
        @invalidDecisionAid()
    ),
    ((error) =>
      @invalidDecisionAid()
    )

  invalidDecisionAid: () ->
    @noDecisionAidFound = true
    @decisionAid = null
    @NavBroadcastService.emitLoadingToRoot(false, @$scope)

  remainingProperties: () ->
    if @decisionAid?
      @decisionAid.minimum_property_count - @checkPropertiesLength()
    else
      null

  checkPropertiesLength: () ->
    @_.size(@propertiesHash)

  orderedUserProperties: () ->
    @_.sortBy @propertiesHash, 'order'

  assignPropertyColor: (property) ->
    colorToUse = null
    @_.find @colors, (color) =>
      if !@_.find(@propertiesHash, (property) => property.color is color)
        colorToUse = color
        return true
      else
        return false
    property.color = colorToUse

  adjustPropertyOrders: (deletedProperty) ->
    @_.each @propertiesHash, (property) ->
      if property.order > deletedProperty.order
        property.order-- 

  selectProperty: (property) ->
    if @propertiesHash[property.id]?
      @adjustPropertyOrders(@propertiesHash[property.id])
      delete @propertiesHash[property.id]
    else
      newProperty = new @DecisionAidUserProperty
      newProperty.initialize(property, @decisionAidUser, @_.toArray(@propertiesHash).length)
      @assignPropertyColor(newProperty)
      @propertiesHash[property.id] = newProperty

    @orderedProperties = @orderedUserProperties()

  submitNext: () ->
    @DecisionAidUserProperty.updateSelections(@_.toArray(@propertiesHash), @decisionAidUser.id).then (decisionAidUserProperties) =>
      if @decisionAid.decision_aid_type is "best_worst_with_prefs_after_choice"
        if @decisionAid.quiz_questions_count > 0
          @$state.go "decisionAidQuiz", {slug: @decisionAidSlug}
        else
          @$state.go "decisionAidSummary", {slug: @decisionAidSlug}
      else
        @$state.go 'decisionAidResults', {slug: @decisionAidSlug}
    ,(error) =>
      console.log error
      
  prevLink: () ->
    if @decisionAid.decision_aid_type is "best_worst_with_prefs_after_choice"
      @$state.go "decisionAidResults", {slug: @decisionAidSlug, sub_decision_order: @decisionAidUser.decision_aid_user_sub_decision_choices_count}
    else if @decisionAid.demographic_questions_count == 0
      @$state.go("decisionAidIntro", {slug: @decisionAidSlug, back: true})
    else
      @$state.go "decisionAidAbout", {slug: @decisionAidSlug, back: true}



module.controller 'DecisionAidPropertiesCtrl', DecisionAidPropertiesCtrl

