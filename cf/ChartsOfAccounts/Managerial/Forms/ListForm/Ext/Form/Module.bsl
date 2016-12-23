﻿
////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

// The procedure sets the form attributes
// visible on the option Use subsystem Production.
//
// Parameters:
// No.
//
&AtServer
Procedure SetVisibleByFOUseProductionSubsystem()
	
	FilterItem = List.SettingsComposer.FixedSettings.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterItem.LeftValue = New DataCompositionField("TypeOfAccount");
	FilterItem.ComparisonType = DataCompositionComparisonType.NotInList;
	FilterItem.Use = True;
	
	ValueList = New ValueList;
	ValueList.Add(Enums.GLAccountsTypes.UnfinishedProduction);
	ValueList.Add(Enums.GLAccountsTypes.IndirectExpenses);
	
	FilterItem.RightValue = ValueList;
	
EndProcedure // SetVisibleByFDUseProductionSubsystem()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

// Procedure - Form event handler "OnCreateAtServer".
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Not Constants.FunctionalOptionUseSubsystemProduction.Get() Then
		
		// FO Use Production subsystem.
		SetVisibleByFOUseProductionSubsystem();
		
	EndIf;
	
EndProcedure // OnCreateAtServer()













