angular.module 'mnoEnterpriseAngular'
  .controller('AppManagementCtrl',
    ($q, $state, $scope, toastr, $stateParams, MnoeConfig, MnoeProductInstances, MnoeProvisioning,
      MnoeOrganizations, MnoeCurrentUser, MnoeMarketplace, PRICING_TYPES, ProvisioningHelper,
      AppSettingsHelper) ->

        vm = @
        vm.isLoading = true
        vm.isOrderHistoryLoading = true
        vm.isCurrentSubscriptionLoading = true
        vm.isSubChanged = true

        vm.dataSharingStatus = ->
          if vm.product.sync_status?.attributes?.status
            'Connected'
          else
            'Disconnected'

        vm.showDataSharingDate = ->
          if vm.product.sync_status?.attributes?.status
            true
          else
            false

        # Return true if the plan has a dollar value
        vm.pricedPlan = (plan) ->
          ProvisioningHelper.pricedPlan(plan)

        vm.toggleSubscriptionNext = (pricingId) ->
          vm.isSubChanged = vm.currentPlanId == pricingId

        vm.nextSubscription = ->
          urlParams =
            subscriptionId: vm.currentSubscription.id
            productId: vm.product.id
            editAction: 'change'

          MnoeProvisioning.setSubscription(vm.currentSubscription)
          if vm.currentSubscription.product.custom_schema?
            $state.go('home.provisioning.additional_details', urlParams)
          else
            $state.go('home.provisioning.confirm', urlParams)

        # ********************** Flags *********************************
        vm.providesStatus = (product) ->
          product.data_sharing || product.subscription

        vm.dataSharingEnabled = ->
          MnoeConfig.isDataSharingEnabled() && vm.product.data_sharing && vm.isAdmin

        vm.manageSubScriptionEnabled = ->
          vm.isAdmin

        vm.orderHistoryEnabled = ->
          vm.isAdmin

        vm.isAddOnSettingShown = ->
          AppSettingsHelper.isAddOnSettingShown(vm.product)

        # ********************** Data Load *********************************
        vm.setUserRole = ->
          vm.isAdmin = MnoeOrganizations.role.atLeastAdmin()

        vm.loadCurrentSubScription = (subscriptions) ->
          vm.currentSubscription = _.find(subscriptions, (sub) -> sub.product?.nid == vm.product.product_nid)
          if vm.currentSubscription
            MnoeProvisioning.initSubscription({productNid: null, subscriptionId: vm.currentSubscription.id}).then(
              (response) ->
                vm.orgCurrency = vm.organization?.currency || MnoeConfig.marketplaceCurrency()
                vm.currentSubscription = response

                MnoeMarketplace.findProduct({id: vm.currentSubscription.product?.id, nid: null}).then(
                  (response) ->
                    vm.currentSubscription.product = response

                    # Filters the pricing plans not containing current currency
                    vm.currentSubscription.product.pricing_plans =  ProvisioningHelper.planForCurrency(vm.currentSubscription.product.pricing_plans, vm.orgCurrency)
                    vm.currentPlanId = vm.currentSubscription.product_pricing_id
                )
            ).finally( -> vm.isCurrentSubscriptionLoading = false)
          else
            vm.isCurrentSubscriptionLoading = false

        vm.loadOrderHistory = ->
          MnoeProvisioning.getProductSubscriptions(vm.product.product_id).then(
            (response) ->
              vm.subscriptionsHistory = response
          ).finally( -> vm.isOrderHistoryLoading = false)

        vm.addOnSettingLauch = ->
          AppSettingsHelper.addOnSettingLauch(vm.product)

        # ********************** Initialize *********************************
        vm.init = ->
          vm.setUserRole()

          productPromise = MnoeProductInstances.getProductInstances()
          subPromise = if vm.isAdmin then MnoeProvisioning.getSubscriptions() else null
          userPromise = MnoeCurrentUser.get()

          $q.all({products: productPromise, subscriptions: subPromise, currentUser: userPromise}).then(
            (response) ->
              vm.product = _.find(response.products, { id: $stateParams.appId })
              unless vm.product
                toastr.error('mno_enterprise.templates.dashboard.app_management.unavailable')
                $state.go('home.apps-management')
                return

              vm.organization = _.find(response.currentUser.organizations, {id: MnoeOrganizations.selectedId})

              # Manage subscription flow
              vm.loadCurrentSubScription(response.subscriptions)

              # Order Histroy flow
              vm.loadOrderHistory() if vm.isAdmin
          ).finally(-> vm.isLoading = false)


        #====================================
        # Post-Initialization
        #====================================
        $scope.$watch MnoeOrganizations.getSelectedId, (val) ->
          if val?
            vm.isLoading = true
            vm.init()

        return
  )
