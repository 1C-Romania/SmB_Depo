
#Region BaseFormProcedures

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	FillingMethod = Parameters.FillingMethod;
	Value = ?(Parameters.Property("Value"), Parameters.Value, Undefined);
	Formula = ?(Parameters.Property("Formula"), Parameters.Formula, Undefined);
	TypeRestriction = ?(Parameters.Property("TypeRestriction"), Parameters.TypeRestriction, Undefined);	
	DocumentBase = ?(Parameters.Property("DocumentBase"), Parameters.DocumentBase, Undefined);		
	TableName = ?(Parameters.Property("TableName"), Parameters.TableName, Undefined);		
	TableKind = ?(Parameters.Property("TableKind"), Parameters.TableKind, Undefined);			
	TableBox = ?(Parameters.Property("TableBox"), Parameters.TableBox, Undefined);				
	TableBoxName = ?(Parameters.Property("TableBoxName"), Parameters.TableBoxName, Undefined);					
		
	Value = TypeRestriction.AdjustValue(Value);
	If TypeRestriction.Types().Count() = 1 Then
		If TypeRestriction.ContainsType(Type("Number")) Then
			Items.Value.Format = "ND=" + TypeRestriction.NumberQualifiers.Digits
			                              + "; NFD=" + TypeRestriction.NumberQualifiers.FractionDigits;
		EndIf;
	EndIf;
	Items.Value.ChooseType     = TypeRestriction.Types().Count() > 1;
	Items.Value.TypeRestriction = TypeRestriction;
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	CopyFormData(ThisForm.FormOwner.Object,Object);
	SetFormulaPresentation();
	UpdateDialog();
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	CopyFormData(Object,ThisForm.FormOwner.Object);	
EndProcedure

#EndRegion

#Region StandardCommonCommands

&AtClient
Procedure UpdateDialog()
	
	If FillingMethod = PredefinedValue("Enum.FieldFillingMethods.Value") Then
		
		Items.GroupValueOrParameter.CurrentPage = Items.GroupValue;
		
	Else
		
		Items.FormulaPresentation.TextEdit = (FillingMethod = PredefinedValue("Enum.FieldFillingMethods.Value"));
		Items.GroupValueOrParameter.CurrentPage = Items.GroupParameter;
		
	EndIf;	
	
EndProcedure

&AtClient
Procedure CommandOK(Command)
	ThisForm.FormOwner.Modified = True;	
	Result = New Structure("TableBoxName,FillingMethod,Value,Formula",TableBoxName,FillingMethod,Value,Formula);
	Close(Result);
EndProcedure

#EndRegion

#Region ItemsEvents

&AtClient
Procedure FormulaPresentationStartChoice(Item, ChoiceData, StandardProcessing)
	DocumentsFormAtClient.EditFormula(ThisForm, FillingMethod, TableKind, TableName, TableBoxName, TypeRestriction,True);
EndProcedure

&AtClient
Procedure EditingFormulaOnClose(Result, AdditionalParameters) Export
	If Result <> Undefined Then
		Formula = Result;
		FormulaPresentationStartChoiceAtServer();			
	EndIf;
EndProcedure

&AtServer
Procedure FormulaPresentationStartChoiceAtServer()
	FormulaPresentation = Catalogs.BookkeepingOperationsTemplates.GetFormulaPresentation(New Structure("FillingMethod, Value", FillingMethod, Formula), TableBoxName,Object.Parameters.Unload());			
EndProcedure

&AtClient
Procedure FormulaPresentationClearing(Item, StandardProcessing)
	Formula = "";
EndProcedure

&AtClient
Procedure FillingMethodOnChange(Item)
	Formula = "";
	FormulaPresentation = "";
	
	UpdateDialog();
EndProcedure

#EndRegion

#Region Other

&AtServer
Procedure SetFormulaPresentation()
	If FillingMethod <> PredefinedValue("Enum.FieldFillingMethods.Value") Then
		FormulaPresentation = Catalogs.BookkeepingOperationsTemplates.GetFormulaPresentation(New Structure("FillingMethod, Value", FillingMethod, Formula), TableBoxName,Object.Parameters.Unload());		
	EndIf;			
EndProcedure

#EndRegion

