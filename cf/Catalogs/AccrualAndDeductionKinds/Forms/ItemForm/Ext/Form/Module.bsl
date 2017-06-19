
#Region ServiceProceduresAndFunctions

// Procedure sets availability of the form items.
//
// Parameters:
//  No.
//
&AtClient
Procedure SetVisibleAndEnabled()
	
	If Object.Type = Tax Then
		
		Object.GLExpenseAccount = Undefined;
		
		Items.GroupFormula.Visible = False;
		Object.Formula = "";
		
		Items.TaxKind.Visible = True;
		
	Else
		
		Items.GroupFormula.Visible = True;
		
		Items.TaxKind.Visible = False;
		Object.TaxKind = Undefined;
		
	EndIf;
	
EndProcedure

// Procedure sets the values dependending on the type selected
//
&AtServer
Procedure OnChangeAccrualKindTypelAtServer(AccrualKindType)
	
	If AccrualKindType = Enums.AccrualAndDeductionTypes.Deduction Then
		
		Object.GLExpenseAccount = ChartsOfAccounts.Managerial.OtherIncome;
		
	Else
		
		Object.GLExpenseAccount = ChartsOfAccounts.Managerial.AdministrativeExpenses;
		
	EndIf;
	
EndProcedure // OnChangeAccrualKindTypeAtServer()

#EndRegion

#Region FormEventsHandlers

// Event handler procedure
// OnCreateAtServer Performs initial form attribute filling.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Tax = Enums.AccrualAndDeductionTypes.Tax;
	Deduction = Enums.AccrualAndDeductionTypes.Deduction;
	
	If Not Constants.FunctionalOptionAccountingDoIncomeTax.Get() Then
		
		ItemOfList = Items.Type.ChoiceList.FindByValue(Enums.AccrualAndDeductionTypes.Tax);
		If ItemOfList <> Undefined Then
			
			Items.Type.ChoiceList.Delete(ItemOfList);
			
		EndIf;
		
	EndIf; 
	
	IsTax = (Object.Type = Tax);
	CommonUseClientServer.SetFormItemProperty(Items, "TaxKind", "Visible", IsTax);
	CommonUseClientServer.SetFormItemProperty(Items, "GroupFormula", "Visible", Not IsTax);
	
	OnChangeAccrualKindTypelAtServer(Object.Type);
	
	// StandardSubsystems.ObjectsAttributesEditProhibition
	ObjectsAttributesEditProhibition.LockAttributes(ThisForm);
	// End StandardSubsystems.ObjectsAttributesEditProhibition
	
EndProcedure // OnCreateAtServer()

// Event handler procedure AfterWriteAtServer
//
&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	// StandardSubsystems.ObjectsAttributesEditProhibition
	ObjectsAttributesEditProhibition.LockAttributes(ThisForm);
	// End StandardSubsystems.ObjectsAttributesEditProhibition
	
EndProcedure // AfterWriteOnServer()

// Event handler procedure NotificationProcessing
//
&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "AccountsChangedAccrualAndDeductionKinds" Then
		
		Object.GLExpenseAccount = Parameter.GLExpenseAccount;
		Modified = True;
		
	EndIf;
	
EndProcedure // NotificationProcessing()

#EndRegion

#Region FormCommandsHandlers

// Procedure is called when clicking the "Edit calculation formula" buttons. 
//
&AtClient
Procedure CommandEditCalculationFormula(Command)
	
	ParametersStructure = New Structure("FormulaText", Object.Formula);
	Notification = New NotifyDescription("CommandEditFormulaOfCalculationEnd",ThisForm);
	OpenForm("Catalog.AccrualAndDeductionKinds.Form.CalculationFormulaEditForm", ParametersStructure,,,,,Notification);
	
EndProcedure // CommandEditCalculationFormulaExecute()

&AtClient
Procedure CommandEditFormulaOfCalculationEnd(FormulaText,Parameters) Export

	If TypeOf(FormulaText) = Type("String") Then
		Object.Formula = FormulaText;
	EndIf;

EndProcedure

#EndRegion

#Region FormAttributesHandlers

// Event handler procedure OnChange of input field LegalEntityIndividual.
//
&AtClient
Procedure TypeOnChange(Item)
	
	SetVisibleAndEnabled();
	OnChangeAccrualKindTypelAtServer(Object.Type);
	
EndProcedure // LegalEntityIndividualOnChange()

#EndRegion

#Region LibrariesHandlers

// StandardSubsystems.ObjectsAttributesEditProhibition
&AtClient
Procedure Attachable_AllowObjectAttributesEditing(Command)
	
	ObjectsAttributesEditProhibitionClient.AllowObjectAttributesEditing(ThisForm);
	
EndProcedure // Attachable_AllowObjectAttributesEditing()
// End

#EndRegion