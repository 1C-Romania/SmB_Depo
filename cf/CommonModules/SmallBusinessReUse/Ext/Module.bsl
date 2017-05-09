//////////////////////////////////////////////////////////////////////////////// 
// EXPORT PROCEDURES AND FUNCTIONS 

// Get value of Session current date
//
Function GetSessionCurrentDate() Export
	
	Return CurrentSessionDate();
	
EndFunction // GetSessionCurrentDate()

// Function returns default value for transferred user and setting.
//
// Parameters:
//  User - current user
//  of application Setup    - a flag for which default value is returned
//
// Returns:
//  Value by default for setup.
//
Function GetValueByDefaultUser(User, Setting) Export

	Query = New Query;
	Query.SetParameter("User", User);
	Query.SetParameter("Setting"   , ChartsOfCharacteristicTypes.UserSettings[Setting]);
	Query.Text = "
	|SELECT
	|	Value
	|FROM
	|	InformationRegister.UserSettings AS RegisterRightsValue
	|
	|WHERE
	|	User = &User
	| AND Setting    = &Setting";

	Selection = Query.Execute().Select();

	EmptyValue = ChartsOfCharacteristicTypes.UserSettings[Setting].ValueType.AdjustValue();

	If Selection.Count() = 0 Then
		
		Return EmptyValue;

	ElsIf Selection.Next() Then

		If Not ValueIsFilled(Selection.Value) Then
			Return EmptyValue;
		Else
			Return Selection.Value;
		EndIf;

	Else
		Return EmptyValue;

	EndIf;

EndFunction // GetUserValueByDefault()

// Function returns default value for transferred user and setting.
//
// Parameters:
//  Setting    - a flag for which default value is returned
//
// Returns:
//  Value by default for setup.
//
Function GetValueOfSetting(Setting) Export

	Query = New Query;
	Query.SetParameter("User", Users.CurrentUser());
	Query.SetParameter("Setting"   , ChartsOfCharacteristicTypes.UserSettings[Setting]);
	Query.Text = "
	|SELECT
	|	Value
	|FROM
	|	InformationRegister.UserSettings AS RegisterRightsValue
	|
	|WHERE
	|	User = &User
	| AND Setting    = &Setting";

	Selection = Query.Execute().Select();

	EmptyValue = ChartsOfCharacteristicTypes.UserSettings[Setting].ValueType.AdjustValue();

	If Selection.Count() = 0 Then
		
		Return EmptyValue;

	ElsIf Selection.Next() Then

		If Not ValueIsFilled(Selection.Value) Then
			Return EmptyValue;
		Else
			Return Selection.Value;
		EndIf;

	Else
		Return EmptyValue;

	EndIf;

EndFunction // GetSettingValue()

// Returns True or False - specified setting of user is in the header.
//
// Parameters:
//  Setting    - a flag for which default value is returned
//
// Returns:
//  Value by default for setup.
//
Function AttributeInHeader(Setting) Export

	Query = New Query;
	Query.SetParameter("User", Users.CurrentUser());
	Query.SetParameter("Setting"   , ChartsOfCharacteristicTypes.UserSettings[Setting]);
	Query.Text = "
	|SELECT
	|	Value
	|FROM
	|	InformationRegister.UserSettings AS RegisterRightsValue
	|
	|WHERE
	|	User = &User
	| AND Setting    = &Setting";

	Selection = Query.Execute().Select();

	DefaultValue = True;

	If Selection.Count() = 0 Then
		
		Return DefaultValue;

	ElsIf Selection.Next() Then

		If Not ValueIsFilled(Selection.Value) Then
			Return DefaultValue;
		Else
			Return Selection.Value = Enums.AttributePositionOnForm.InHeader;
		EndIf;

	Else
		Return DefaultValue;

	EndIf;

EndFunction // GetUserValueByDefault()

// Function returns the flag of commercial equipment use.
//
Function UsePeripherals() Export
	
	 Return GetFunctionalOption("UsePeripherals")
		   AND TypeOf(Users.AuthorizedUser()) = Type("CatalogRef.Users");
	 
EndFunction // UsePeripherals()

// Function receives parameters of CR cash register.
//
Function CashRegistersGetParameters(CashCR) Export
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	CASE
	|		WHEN CashRegisters.CashCRType = VALUE(Enum.CashCRTypes.FiscalRegister)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS IsFiscalRegister,
	|	CashRegisters.Peripherals AS DeviceIdentifier,
	|	CashRegisters.UseWithoutEquipmentConnection AS UseWithoutEquipmentConnection
	|FROM
	|	Catalog.CashRegisters AS CashRegisters
	|WHERE
	|	CashRegisters.Ref = &Ref";
	
	Query.SetParameter("Ref", CashCR);
	
	Result = Query.Execute();
	Selection = Result.Select();
	
	If Selection.Next() Then
		
		Return New Structure(
			"DeviceIdentifier,
			|UseWithoutEquipmentConnection,
			|ThisIsFiscalRegister",
			Selection.DeviceIdentifier,
			Selection.UseWithoutEquipmentConnection,
			Selection.IsFiscalRegister
		);
		
	Else
		
		Return New Structure(
			"DeviceIdentifier,
			|UseWithoutEquipmentConnection,
			|ThisIsFiscalRegister",
			Catalogs.Peripherals.EmptyRef(),
			False,
			False
		);
		
	EndIf;
	
EndFunction // CashRegistersGetParameters()

// Function checks if it is necessary to monitor the contracts of counterparties.
//
Function CounterpartyContractsControlNeeded() Export
	
	SetPrivilegedMode(True);
	
	If (NOT CommonUseReUse.DataSeparationEnabled() AND Not GetFunctionalOption("UseDataSynchronization")) Then
		Return False;
	EndIf;
	
	Return ExchangeWithBookkeepingConfigured();
	
EndFunction

// Function checks the existence of nodes in exchange plans with Accounting department of the company.
//
Function ExchangeWithBookkeepingConfigured() Export
	
	Return False;
	
EndFunction

// Function returns the value of advances offset setup.
//
// Parameters:
//  Setting    - a flag for which default value is returned
//
// Returns:
//  Value by default for setup.
//
Function GetAdvanceOffsettingSettingValue() Export
	
	OffsetAutomatically = GetValueOfSetting("OffsetAdvancesDebtsAutomatically");
	If Not ValueIsFilled(OffsetAutomatically) Then
		OffsetAutomatically = Constants.OffsetAdvancesDebtsAutomatically.Get();
	EndIf;
	
	Return OffsetAutomatically;
	
EndFunction // GetSettingValue()

// Function determines for which operation mode of the application synchronization settings should be used.
//
Function SettingsForSynchronizationSaaS() Export

	Return GetFunctionalOption("StandardSubsystemsSaaS");

EndFunction // SynchronizationSaaS()

// PROCEDURES AND FUNCTIONS FOR WORK WITH VAT RATES

// Get value of VAT rate.
//
Function GetVATRateValue(VATRate) Export
	
	Return ?(ValueIsFilled(VATRate), VATRate.Rate, 0);

EndFunction // GetVATRateValue()

// Function returns VAT rate - Without VAT.
//
Function GetVATRateWithoutVAT() Export
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	VATRates.Ref AS VATRate
	|FROM
	|	Catalog.VATRates AS VATRates
	|WHERE
	|	VATRates.NotTaxable
	|	AND VATRates.Rate = 0";
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Return Selection.VATRate;
	EndIf;
	
	Return Undefined;
	
EndFunction // GetVATRateWithoutVAT()

// Function returns VAT rate - Zero.
//
Function GetVATRateZero() Export
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	VATRates.Ref AS VATRate
	|FROM
	|	Catalog.VATRates AS VATRates
	|WHERE
	|	(NOT VATRates.NotTaxable)
	|	AND VATRates.Rate = 0";
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Return Selection.VATRate;
	EndIf;
	
	Return Undefined;
	
EndFunction // GetVATRateZero()

// Function returns VAT rate - Estimated.
//
Function GetVATRateEstimated(VATRate) Export
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	CalculatedVATRates.Ref AS VATRate
	|FROM
	|	Catalog.VATRates AS CalculatedVATRates
	|WHERE
	|	CalculatedVATRates.Calculated
	|	AND Not calculatedVATRates.NotTaxable
	|	AND CalculatedVATRates.Rate = &Rate";
	
	Query.SetParameter("Rate", VATRate.Rate);
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Return Selection.VATRate;
	EndIf;
	
	Return VATRate;
	
EndFunction // GetVATRateEstimated()

// PROCEDURES AND FUNCTIONS FOR WORK WITH CONSTANTS

// Function returns the national currency
//
Function GetNationalCurrency() Export
	
	Return Constants.NationalCurrency.Get();
	
EndFunction // GetNationalCurrency()

// Function returns accounting currency
//
Function GetAccountCurrency() Export
	
	Return Constants.AccountingCurrency.Get();
	
EndFunction // GetAccountCurrency()

// Function returns the state in progress for customer orders
//
Function GetStatusInProcessOfCustomerOrders() Export
	
	Return Constants.CustomerOrdersInProgressStatus.Get();
	
EndFunction // GetStateInCustomerOrdersProcess()

// Function returns the state completed for customer orders
//
Function GetStatusCompletedCustomerOrders() Export
	
	Return Constants.CustomerOrdersCompletedStatus.Get();
	
EndFunction // GetStateCompletedCustomerOrders()
// 
