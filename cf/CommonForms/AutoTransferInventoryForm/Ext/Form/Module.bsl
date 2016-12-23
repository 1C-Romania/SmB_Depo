
//////////////////////////////////////////////////////////////////////////////// 
// PROCEDURES AND FUNCTIONS 

&AtServer
// Procedure fills the form parameters.
//
Procedure GetFormValuesOfParameters()
	
	TransferSource = Parameters.TransferSource;
	TransferRecipient = Parameters.TransferRecipient;
	RecipientOfWastes = Parameters.RecipientOfWastes;
	WriteOffToExpensesSource = Parameters.WriteOffToExpensesSource;
	WriteOffToExpensesRecipient	= Parameters.WriteOffToExpensesRecipient;
	PassToOperationSource = Parameters.PassToOperationSource;
	PassToOperationRecipient = Parameters.PassToOperationRecipient;
	ReturnFromOperationSource = Parameters.ReturnFromOperationSource;
	ReturnFromOperationRecipient = Parameters.ReturnFromOperationRecipient;
	
	TransferSourceCell = Parameters.TransferSourceCell;
	TransferRecipientCell = Parameters.TransferRecipientCell;
	DisposalsRecipientCell = Parameters.DisposalsRecipientCell;
	WriteOffToExpensesSourceCell = Parameters.WriteOffToExpensesSourceCell;
	WriteOffToExpensesRecipientCell = Parameters.WriteOffToExpensesRecipientCell;
	PassToOperationSourceCell = Parameters.PassToOperationSourceCell;
	PassToOperationRecipientCell = Parameters.PassToOperationRecipientCell;
	ReturnFromOperationSourceCell = Parameters.ReturnFromOperationSourceCell;
	ReturnFromOperationRecipientCell = Parameters.ReturnFromOperationRecipientCell;
	
EndProcedure // GetFormParametersValues()	

&AtClient
// Function puts the autotransfer parameters in object.
//
Function WriteAutotransferParametersToObject()
	
	ParametersAutoshift = New Structure;
	ParametersAutoshift.Insert("TransferSource", TransferSource);
	ParametersAutoshift.Insert("TransferRecipient", TransferRecipient);
	ParametersAutoshift.Insert("RecipientOfWastes", RecipientOfWastes);
	ParametersAutoshift.Insert("WriteOffToExpensesSource", WriteOffToExpensesSource);
	ParametersAutoshift.Insert("WriteOffToExpensesRecipient", WriteOffToExpensesRecipient);
	ParametersAutoshift.Insert("PassToOperationSource", PassToOperationSource);
	ParametersAutoshift.Insert("PassToOperationRecipient", PassToOperationRecipient);
	ParametersAutoshift.Insert("ReturnFromOperationSource", ReturnFromOperationSource);
	ParametersAutoshift.Insert("ReturnFromOperationRecipient", ReturnFromOperationRecipient);
	
	ParametersAutoshift.Insert("TransferSourceCell", TransferSourceCell);
	ParametersAutoshift.Insert("TransferRecipientCell", TransferRecipientCell);
	ParametersAutoshift.Insert("DisposalsRecipientCell", DisposalsRecipientCell);
	ParametersAutoshift.Insert("WriteOffToExpensesSourceCell", WriteOffToExpensesSourceCell);
	ParametersAutoshift.Insert("WriteOffToExpensesRecipientCell", WriteOffToExpensesRecipientCell);
	ParametersAutoshift.Insert("PassToOperationSourceCell", PassToOperationSourceCell);
	ParametersAutoshift.Insert("PassToOperationRecipientCell", PassToOperationRecipientCell);
	ParametersAutoshift.Insert("ReturnFromOperationSourceCell", ReturnFromOperationSourceCell);
	ParametersAutoshift.Insert("ReturnFromOperationRecipientCell", ReturnFromOperationRecipientCell);
	
	ParametersAutoshift.Insert("Modified", Modified);
	
	Return ParametersAutoshift;
	
EndFunction // WriteAutotransferParametersToObject()	

&AtServerNoContext
// It receives data set from the server for the StructuralUnitOnChange procedure.
//
Function GetDataStructuralUnitOnChange(Warehouse)
	
	StructureData = New Structure();
	
	If Not ValueIsFilled(Warehouse)
		OR Warehouse.OrderWarehouse
		OR Warehouse.StructuralUnitType = Enums.StructuralUnitsTypes.Retail
		OR Warehouse.StructuralUnitType = Enums.StructuralUnitsTypes.RetailAccrualAccounting Then
		
		StructureData.Insert("OrderWarehouse", False);
		
	Else
		
		StructureData.Insert("OrderWarehouse", True);
		
	EndIf;	
	
	Return StructureData;
	
EndFunction // GetDataStructuralUnitOnChange()

&AtServer
// Procedure sets availability of the form items.
//
// Parameters:
//  No.
//
Procedure SetVisibleAndEnabled()

	If Parameters.StructuralUnitType = Enums.StructuralUnitsTypes.Warehouse Then
		
		Items.WriteOffToExpensesSource.Visible = False;
		Items.WriteOffToExpensesSourceCell.Visible = False;
		WriteOffToExpensesSource = Undefined;
		WriteOffToExpensesSourceCell = Undefined;
		
		If Not Constants.FunctionalOptionAccountingByMultipleDivisions.Get() Then
		
			Items.WriteOffToExpensesRecipient.Visible = False;
			Items.WriteOffToExpensesRecipientCell.Visible = False;
			WriteOffToExpensesRecipient = Undefined;
			WriteOffToExpensesRecipientCell = Undefined;
			
		EndIf;	
			
		Items.PassToOperationSource.Visible = False;
		Items.PassToOperationSourceCell.Visible = False;
		PassToOperationSource = Undefined;
		PassToOperationSourceCell = Undefined;
		
		If Not Constants.FunctionalOptionAccountingByMultipleDivisions.Get() Then
		
			Items.PassToOperationRecipient.Visible = False;
			Items.PassToOperationRecipientCell.Visible = False;
			PassToOperationRecipient = Undefined;
			PassToOperationRecipientCell = Undefined;
			
		EndIf;		
		
		Items.ReturnFromOperationRecipient.Visible = False;
		Items.ReturnFromOperationRecipientCell.Visible = False;
		ReturnFromOperationRecipient = Undefined;
		ReturnFromOperationRecipientCell = Undefined;
		
		If Not Constants.FunctionalOptionAccountingByMultipleDivisions.Get() Then
		
			Items.ReturnFromOperationSource.Visible = False;
			Items.ReturnFromOperationSourceCell.Visible = False;
			ReturnFromOperationSource = Undefined;
			ReturnFromOperationSourceCell = Undefined;
			
		EndIf;		
		
	ElsIf Parameters.StructuralUnitType = Enums.StructuralUnitsTypes.Division Then	
		
		Items.WriteOffToExpensesRecipient.Visible = False;
		Items.WriteOffToExpensesRecipientCell.Visible = False;
		WriteOffToExpensesRecipient = Undefined;
		WriteOffToExpensesRecipientCell = Undefined;
		
		If Not Constants.FunctionalOptionAccountingByMultipleWarehouses.Get() Then
			
			Items.WriteOffToExpensesSource.Visible = False;
			Items.WriteOffToExpensesSourceCell.Visible = False;
			WriteOffToExpensesSource = Undefined;
			WriteOffToExpensesSourceCell = Undefined;
			
		EndIf;		
		
		Items.PassToOperationRecipient.Visible = False;
		Items.PassToOperationRecipientCell.Visible = False;
		PassToOperationRecipient = Undefined;
		PassToOperationRecipientCell = Undefined;
		
		If Not Constants.FunctionalOptionAccountingByMultipleWarehouses.Get() Then
			
			Items.PassToOperationSource.Visible = False;
			Items.PassToOperationSourceCell.Visible = False;
			PassToOperationSource = Undefined;
			PassToOperationSourceCell = Undefined;
			
		EndIf;
		
		Items.ReturnFromOperationSource.Visible = False;
		Items.ReturnFromOperationSourceCell.Visible = False;
		ReturnFromOperationSource = Undefined;
		ReturnFromOperationSourceCell = Undefined;
		
		If Not Constants.FunctionalOptionAccountingByMultipleWarehouses.Get() Then
			
			Items.ReturnFromOperationRecipient.Visible = False;
			Items.ReturnFromOperationRecipientCell.Visible = False;
			ReturnFromOperationRecipient = Undefined;
			ReturnFromOperationRecipientCell = Undefined;
			
		EndIf;
		
	ElsIf Parameters.StructuralUnitType = Enums.StructuralUnitsTypes.Retail
		OR Parameters.StructuralUnitType = Enums.StructuralUnitsTypes.RetailAccrualAccounting Then
		
		Items.RecipientOfWastes.Visible = False;
		Items.DisposalsRecipientCell.Visible = False;		
		RecipientOfWastes = Undefined;
		DisposalsRecipientCell = Undefined;
		
		Items.WriteOffToExpensesSource.Visible = False;
		Items.WriteOffToExpensesSourceCell.Visible = False;
		WriteOffToExpensesSource = Undefined;
		WriteOffToExpensesSourceCell = Undefined;
		
		Items.WriteOffToExpensesRecipient.Visible = False;
		Items.WriteOffToExpensesRecipientCell.Visible = False;
		WriteOffToExpensesRecipient = Undefined;
		WriteOffToExpensesRecipientCell = Undefined;
		
		Items.PassToOperationSource.Visible = False;
		Items.PassToOperationSourceCell.Visible = False;
		PassToOperationSource = Undefined;
		PassToOperationSourceCell = Undefined;
						
		Items.PassToOperationRecipient.Visible = False;
		Items.PassToOperationRecipientCell.Visible = False;
		PassToOperationRecipient = Undefined;
		PassToOperationRecipientCell = Undefined;
		
		Items.ReturnFromOperationSource.Visible = False;
		Items.ReturnFromOperationSourceCell.Visible = False;
		ReturnFromOperationSource = Undefined;
		ReturnFromOperationSourceCell = Undefined;	
		
		Items.ReturnFromOperationRecipient.Visible = False;
		Items.ReturnFromOperationRecipientCell.Visible = False;
		ReturnFromOperationRecipient = Undefined;
		ReturnFromOperationRecipientCell = Undefined;
		
	EndIf;	
	
	If Not ValueIsFilled(TransferSource)
		OR TransferSource.OrderWarehouse
		OR TransferSource.StructuralUnitType = Enums.StructuralUnitsTypes.Retail
		OR TransferSource.StructuralUnitType = Enums.StructuralUnitsTypes.RetailAccrualAccounting Then
		
		Items.TransferSourceCell.Enabled = False;
		
	EndIf;
	
	If Not ValueIsFilled(TransferRecipient)
		OR TransferRecipient.OrderWarehouse
		OR TransferRecipient.StructuralUnitType = Enums.StructuralUnitsTypes.Retail
		OR TransferRecipient.StructuralUnitType = Enums.StructuralUnitsTypes.RetailAccrualAccounting Then
		
		Items.TransferRecipientCell.Enabled = False;
		
	EndIf;
		
	If Not ValueIsFilled(RecipientOfWastes)
		OR RecipientOfWastes.OrderWarehouse Then
		
		Items.DisposalsRecipientCell.Enabled = False;
		
	EndIf;	
		
	If Not ValueIsFilled(WriteOffToExpensesSource)
		OR WriteOffToExpensesSource.OrderWarehouse Then
		
		Items.WriteOffToExpensesSourceCell.Enabled = False;
		
	EndIf;
	
	If Not ValueIsFilled(WriteOffToExpensesRecipient) Then
		
		Items.WriteOffToExpensesRecipientCell.Enabled = False;
		
	EndIf;
		
	If Not ValueIsFilled(PassToOperationSource)
		OR PassToOperationSource.OrderWarehouse Then
		
		Items.PassToOperationSourceCell.Enabled = False;
		
	EndIf;	
	
	If Not ValueIsFilled(PassToOperationRecipient) Then
		
		Items.PassToOperationRecipientCell.Enabled = False;
		
	EndIf;
	
	If Not ValueIsFilled(ReturnFromOperationSource) Then
		
		Items.ReturnFromOperationSourceCell.Enabled = False;
		
	EndIf;	
	
	If Not ValueIsFilled(ReturnFromOperationRecipient)
		OR ReturnFromOperationRecipient.OrderWarehouse Then
		
		Items.ReturnFromOperationRecipientCell.Enabled = False;
		
	EndIf;
	
EndProcedure // SetVisibleAndEnabled()	

&AtServer
// The procedure sets the form attributes
// visible on the option Use subsystem Production.
//
// Parameters:
// No.
//
Procedure SetVisibleByFOUseProductionSubsystem()
	
	// Production.
	If Constants.FunctionalOptionUseSubsystemProduction.Get() Then
		
		// Warehouse. Setting the method of structural unit selection depending on FO.
		If Not Constants.FunctionalOptionAccountingByMultipleDivisions.Get()
			AND Not Constants.FunctionalOptionAccountingByMultipleWarehouses.Get() Then
			
			Items.TransferSource.ListChoiceMode = True;
			Items.TransferSource.ChoiceList.Add(Catalogs.StructuralUnits.MainDivision);
			Items.TransferSource.ChoiceList.Add(Catalogs.StructuralUnits.MainWarehouse);
			
			Items.TransferRecipient.ListChoiceMode = True;
			Items.TransferRecipient.ChoiceList.Add(Catalogs.StructuralUnits.MainDivision);
			Items.TransferRecipient.ChoiceList.Add(Catalogs.StructuralUnits.MainWarehouse);
			
			Items.RecipientOfWastes.ListChoiceMode = True;
			Items.RecipientOfWastes.ChoiceList.Add(Catalogs.StructuralUnits.MainDivision);
			Items.RecipientOfWastes.ChoiceList.Add(Catalogs.StructuralUnits.MainWarehouse);
		
		EndIf;
		
	Else
		
		If Constants.FunctionalOptionAccountingByMultipleWarehouses.Get() Then
			
			NewArray = New Array();
			NewArray.Add(Enums.StructuralUnitsTypes.Warehouse);
			NewArray.Add(Enums.StructuralUnitsTypes.Retail);
			NewArray.Add(Enums.StructuralUnitsTypes.RetailAccrualAccounting);
			ArrayTypesOfStructuralUnits = New FixedArray(NewArray);
			NewParameter = New ChoiceParameter("Filter.StructuralUnitType", ArrayTypesOfStructuralUnits);
			NewArray = New Array();
			NewArray.Add(NewParameter);
			NewParameters = New FixedArray(NewArray);
			
			Items.TransferSource.ChoiceParameters = NewParameters;
			Items.TransferRecipient.ChoiceParameters = NewParameters;
			Items.RecipientOfWastes.ChoiceParameters = NewParameters;
			
		Else
			
			Items.TransferSource.Visible = False;
			Items.TransferRecipient.Visible = False;
			Items.RecipientOfWastes.Visible = False;
			
		EndIf;
		
		If Parameters.StructuralUnitType = Enums.StructuralUnitsTypes.Division Then
			
			Items.TransferAssemblingDisassembling.Visible = False;
			
		EndIf;
		
	EndIf;
	
EndProcedure // SetVisibleByFDUseProductionSubsystem()

//////////////////////////////////////////////////////////////////////////////// 
// EVENT HANDLERS

&AtServer
// Procedure - event handler OnCreateAtServer of the form.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	GetFormValuesOfParameters();
	
	SetVisibleAndEnabled();
	
	// FO Use Production subsystem.
	SetVisibleByFOUseProductionSubsystem();
	
EndProcedure // OnCreateAtServer()

&AtClient
//Procedure - OK button click handler.
//
Procedure CommandOK(Command)
	
	Close(WriteAutotransferParametersToObject());
	
EndProcedure // CommandOK()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF FORM ATTRIBUTES

&AtClient
// Procedure - event handler OnChange of TransferSource field.
//
Procedure TransferSourceOnChange(Item)
	
	StructureData = GetDataStructuralUnitOnChange(TransferSource);
	Items.TransferSourceCell.Enabled = StructureData.OrderWarehouse;

EndProcedure // TransferSourceOnChange()

&AtClient
// Procedure - event handler OnChange of TransferSource field.
//
Procedure TransferRecipientOnChange(Item)
	
	StructureData = GetDataStructuralUnitOnChange(TransferRecipient);
	Items.TransferRecipientCell.Enabled = StructureData.OrderWarehouse;
	
EndProcedure // TransferRecipientOnChange()

&AtClient
// Procedure - event handler OnChange of RecipientOfWastes field.
//
Procedure RecipientOfWastesOnChange(Item)
	
	StructureData = GetDataStructuralUnitOnChange(RecipientOfWastes);
	Items.DisposalsRecipientCell.Enabled = StructureData.OrderWarehouse;
	
EndProcedure // RecipientOfWastesOnChange()

&AtClient
// Procedure - event handler OnChange of WriteOffSource field.
//
Procedure WriteOffToExpensesSourceOnChange(Item)
	
	StructureData = GetDataStructuralUnitOnChange(WriteOffToExpensesSource);
	Items.WriteOffToExpensesSourceCell.Enabled = StructureData.OrderWarehouse;
	
EndProcedure // WriteOffToExpensesSourceOnChange()

&AtClient
// Procedure - event handler OnChange of WriteOffToExpensesRecipient field.
//
Procedure WriteOffToExpensesRecipientOnChange(Item)
	
	If ValueIsFilled(WriteOffToExpensesRecipient) Then
		Items.WriteOffToExpensesRecipientCell.Enabled = True;
	Else
		Items.WriteOffToExpensesRecipientCell.Enabled = False;
	EndIf;	
	
EndProcedure // WriteOffToExpensesRecipientOnChange()

&AtClient
// Procedure - event handler OnChange of PassToOperationSource field.
//
Procedure PassToOperationSourceOnChange(Item)
	
	StructureData = GetDataStructuralUnitOnChange(PassToOperationSource);
	Items.PassToOperationSourceCell.Enabled = StructureData.OrderWarehouse;
	
EndProcedure // PassToOperationSourceOnChange()

&AtClient
// Procedure - event handler OnChange of PassToOperationRecipient field.
//
Procedure PassToOperationRecipientOnChange(Item)
	
	If ValueIsFilled(PassToOperationRecipient) Then
		Items.PassToOperationRecipientCell.Enabled = True;
	Else
		Items.PassToOperationRecipientCell.Enabled = False;
	EndIf;	
	
EndProcedure // PassToOperationRecipientOnChange()

&AtClient
// Procedure - event handler OnChange of ReturnFromOperationSource field.
//
Procedure ReturnFromOperationSourceOnChange(Item)
	
	If ValueIsFilled(ReturnFromOperationSource) Then
		Items.ReturnFromOperationSourceCell.Enabled = True;
	Else
		Items.ReturnFromOperationSourceCell.Enabled = False;
	EndIf;	
	
EndProcedure // ReturnFromOperationSourceOnChange()

&AtClient
// Procedure - event handler OnChange of ReturnFromOperationRecipient field.
//
Procedure ReturnFromOperationRecipientOnChange(Item)
	
	StructureData = GetDataStructuralUnitOnChange(ReturnFromOperationRecipient);
	Items.ReturnFromOperationRecipientCell.Enabled = StructureData.OrderWarehouse;
	
EndProcedure // ReturnFromOperationRecipientOnChange()

&AtClient
// Procedure - event handler Open of TransferSource field.
//
Procedure TransferSourceOpening(Item, StandardProcessing)
	
	If Items.TransferSource.ListChoiceMode
		AND Not ValueIsFilled(TransferSource) Then
		
		StandardProcessing = False;
		
	EndIf;
	
EndProcedure // TransferSourceOpening()

&AtClient
// Procedure - event handler Open of TransferRecipient field.
//
Procedure TransferRecipientOpening(Item, StandardProcessing)
	
	If Items.TransferRecipient.ListChoiceMode
		AND Not ValueIsFilled(TransferRecipient) Then
		
		StandardProcessing = False;
		
	EndIf;
	
EndProcedure // TransferRecipientOpening()

&AtClient
// Procedure - event handler Open of RecipientOfWastes field.
//
Procedure RecipientOfWastesOpening(Item, StandardProcessing)
	
	If Items.RecipientOfWastes.ListChoiceMode
		AND Not ValueIsFilled(RecipientOfWastes) Then
		
		StandardProcessing = False;
		
	EndIf;
	
EndProcedure // RecipientOfWastesOpening()













