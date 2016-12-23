////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

&AtClient
// Procedure inserts the text which is passed as a parameter to the tabular document field.
// 
Procedure InsertTextInFormula(Indicator)
	
	FormulaText = FormulaText + " [" + TrimAll(Indicator) + "] ";
			
EndProcedure // InsertTextInFormula()	

&AtServerNoContext
// Function receives the indicator ID.
//
Function GetIndicatorID(DataStructure)
	
	Return TrimAll(DataStructure.SelectedRow.ID);

EndFunction // GetIndicatorID()

&AtServer
// Procedure - event handler OnCreateAtServer of the form.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	TextIndicators = NStr("en='To place the indicator in the formula, click it';ru='Для размещения показателя в формуле дважды щелкните левой кнопкой мыши'");
	
	If Parameters.Property("FormulaText") Then
		
		FormulaText = Parameters.FormulaText;
		
	EndIf;	
	
EndProcedure // OnCreateAtServer()

///////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM (BUTTON) ITEM EVENT HANDLERS

&AtClient
// Procedure - button click handler OK
//
Procedure CommandOK(Command)
	
	Close(FormulaText);
	
EndProcedure // CommandOKExecute()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - DYNAMIC LIST EVENT HANDLERS CALCULATION PARAMETERS

&AtClient
// Procedure - event handler Selection of dynamic list ProductParameters.
//
Procedure CalculationsParametersSelection(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	DataStructure = New Structure("SelectedRow", SelectedRow);
	
	TextInFormula = GetIndicatorID(DataStructure);
    InsertTextInFormula(TextInFormula);

EndProcedure // CalculationsParametersSelection()






















