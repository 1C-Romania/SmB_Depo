////////////////////////////////////////////////////////////////////////////////
// The subsystem "Basic functionality".
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProgramInterface

////////////////////////////////////////////////////////////////////////////////
// Execution result processor.

// It generates the performance result template.
//
// Returns: 
//   Result - Structure - See StandardSubsystemsClient.ShowPerformanceResult().
//
Function NewExecutionResult(Result = Undefined) Export
	If Result = Undefined Then
		Result = New Structure;
	EndIf;
	
	Result.Insert("OutputNotification",     New Structure("Use, Title, Ref, Text, Picture", False));
	Result.Insert("OutputMessages",      New Structure("Use, Text, PathToFormAttribute", False));
	Result.Insert("OutputWarning", New Structure("Use, Title, Text, PathToFormAttribute, ErrorsText", False));
	Result.Insert("NotificationForms",                New Structure("Use, EventName, Parameter, Source", False));
	Result.Insert("NotifyDynamictLists", New Structure("Use, ReferenceOrType", False));
	
	Return Result;
EndFunction

// It adds info of the types that shall be updated in dynamic lists to the structure.
//   The action is performed on the client after calling StandardSubsystemsClient.ShowPerformanceResult(Result).
//
// Parameters:
//   Result - Structure - See StandardSubsystemsClient.ShowPerformanceResult().
//   ModifiedObject - Array - Changed object refs.
//
Procedure NotifyDynamicLists(Result, ModifiedObjects) Export
	If TypeOf(ModifiedObjects) <> Type("Array") Or ModifiedObjects.Count() = 0 Then
		Return;
	EndIf;
	
	If Not Result.Property("NotifyDynamictLists") Then
		Result.Insert("NotifyDynamictLists", New Structure("Use, ReferenceOrType", False));
	EndIf;
	Notification = Result.NotifyDynamictLists;
	Notification.Use = True;
	
	Value = Notification.ReferenceOrType;
	ValueIsFilled = ValueIsFilled(Value);
	
	If ModifiedObjects.Count() = 1 AND Not ValueIsFilled Then
		Notification.ReferenceOrType = ModifiedObjects[0];
	Else
		// Notification conversion to the array.
		ValueType = TypeOf(Value);
		If ValueType <> Type("Array") Then
			Notification.ReferenceOrType = New Array;
			If ValueIsFilled Then
				Notification.ReferenceOrType.Add(?(ValueType = Type("Type"), Value, ValueType));
			EndIf;
		EndIf;
		
		// Adding changed object types.
		For Each ModifiedObject In ModifiedObjects Do
			ModifiedObjectType = TypeOf(ModifiedObject);
			If Notification.ReferenceOrType.Find(ModifiedObjectType) = Undefined Then
				Notification.ReferenceOrType.Add(ModifiedObjectType);
			EndIf;
		EndDo;
	EndIf;
EndProcedure

// It complements the structure with the info of the event of which all opened forms shall be notified.
//   The action is performed on the client after calling StandardSubsystemsClient.ShowPerformanceResult(Result).
//
// Parameters:
//   Result  - Structure - See StandardSubsystemsClient.ShowPerformanceResult().
//   EventName - String - Event name used for primary message identification by the receiving forms.
//   Parameter   - Arbitrary - Set of data used by the receiving form for the content update.
//   Source   - Arbitrary - Notification source, for example, form-source.
//
Procedure ExecutionResultAddNotificationOfOpenForms(Result, EventName, Parameter = Undefined, Source = Undefined) Export
	If Not Result.Property("NotificationForms") Then
		Result.Insert("NotificationForms", New Array);
	ElsIf TypeOf(Result.NotificationForms) = Type("Structure") Then // Structure to the structure array.
		NotificationForms = Result.NotificationForms;
		Result.NotificationForms = New Array;
		Result.NotificationForms.Add(NotificationForms);
	EndIf;
	NotificationForms = New Structure("Use, EventName, Parameter, Source", True, EventName, Parameter, Source);
	Result.NotificationForms.Add(NotificationForms);
EndProcedure

// It adds info of the tree nodes to be expanded to the structure.
//   The action is performed on the client after calling StandardSubsystemsClient.ShowPerformanceResult(Result).
//
// Parameters:
//   Result - Structure - See StandardSubsystemsClient.ShowPerformanceResult().
//   TableName - String - Form table name (value tree) where the node shall be expanded.
//   ID - Arbitrary - Optional. Tree string ID to be expanded.
//       If "*" is specified, then all nodes of the top level will be expanded.
//       If Undefined is specified, the tree strings will not be expanded.
//       Value by default: "*".
//   WithSubordinate - Boolean - Optional. Whether to expand the subordinate nodes or not.
//       Value by default: False (do not expand subordinate nodes).
//
Procedure CollapseTreeNodes(Result, TableName, ID = "*", WithSubordinate = False) Export
	If ID = Undefined Then
		Return;
	EndIf;
	
	If Not Result.Property("ExpandableNodes") Then
		Result.Insert("ExpandableNodes", New Array);
	EndIf;
	
	ExpandableNode = New Structure("TableName, Identifier, WithSubordinate");
	ExpandableNode.TableName = TableName;
	ExpandableNode.Identifier = ID;
	ExpandableNode.WithSubordinate = WithSubordinate;
	
	Result.ExpandableNodes.Add(ExpandableNode);
EndProcedure

// It adds info required to display warnings or error text to the structure.
//   The action is performed on the client after calling StandardSubsystemsClient.ShowPerformanceResult(Result).
//
// Parameters:
//   Result - Structure - See StandardSubsystemsClient.ShowPerformanceResult().
//   Text               - String - Notification text.
//   ErrorsText         - String - Optional. Texts of errors that the user can view if necessary.
//   Title           - String - Optional. Window title.
//   PathToAttributeForms - String - Optional. Path to the form attribute which value caused an error.
//
Procedure DisplayWarning(Result, Text, ErrorsText = "", Title = "", PathToAttributeForms = "") Export
	OutputWarning = CommonUseClientServer.StructureProperty(Result, "OutputWarning");
	If OutputWarning = Undefined Then
		OutputWarning = New Structure("Use, Title, Text, PathToFormAttribute, ErrorsText", False);
		Result.Insert("OutputWarning", OutputWarning);
	EndIf;
	OutputWarning.Use = True;
	OutputWarning.Title = Title;
	OutputWarning.Text = Text;
	OutputWarning.ErrorsText = ErrorsText;
	OutputWarning.PathToAttributeForms = PathToAttributeForms;
EndProcedure

// It complements the structure with the info required to display the message of improperly filled form fields.
//   The action is performed on the client after calling StandardSubsystemsClient.ShowPerformanceResult(Result).
//
// Parameters:
//   Result - Structure - See StandardSubsystemsClient.ShowPerformanceResult().
//   Text               - String - Message text.
//   PathToAttributeForms - String - Optional. Path to the form attribute which value caused an error.
//
Procedure ShowMessage(Result, Text, PathToAttributeForms = "") Export
	OutputMessages = CommonUseClientServer.StructureProperty(Result, "OutputMessages");
	If OutputMessages = Undefined Then
		OutputMessages = New Structure("Use, Text, PathToFormAttribute", False);
		Result.Insert("OutputMessages", OutputMessages);
	EndIf;
	OutputMessages.Use = True;
	OutputMessages.Text = Text;
	OutputMessages.PathToAttributeForms = PathToAttributeForms;
EndProcedure

// It adds info required for the popup notification display to the structure.
//   The action is performed on the client after calling StandardSubsystemsClient.ShowPerformanceResult(Result).
//
// Parameters:
//   Result - Structure - See StandardSubsystemsClient.ShowPerformanceResult().
//   Title - String    - Notification title.
//   Text     - String    - Notification text.
//   Refs    - String    - URL to go to the configuration object.
//   Picture  - Picture  - Notification picture.
//
Procedure DisplayNotification(Result, Title, Text = "", Picture = Undefined, Ref = "") Export
	OutputNotification = CommonUseClientServer.StructureProperty(Result, "OutputNotification");
	If OutputNotification = Undefined Then
		OutputNotification = New Structure("Use, Title, Ref, Text, Picture", False);
		Result.Insert("OutputNotification", OutputNotification);
	EndIf;
	OutputNotification.Use = True;
	OutputNotification.Title     = Title;
	OutputNotification.Ref        = Ref;
	OutputNotification.Text         = Text;
	OutputNotification.Picture      = Picture;
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Spreadsheet document

// It calculates the amount of the selected cells and returns its presentation.
//
// Parameters:
//   SpreadsheetDocument - SpreadsheetDocument - Table for which the cell amount is calculated.
//   SelectedAreas
//       - Undefined - When calling from the client this parameter will be automatically defined.
//       - Array - When calling from the server the areas precalculated
//           on the client using
//           ReportsClient function shall be transferred to this parameter.SelectedAreas(SpreadsheetDocument).
//
// Returns: 
//   String - Amount presentation for the selected cells.
//
// See also:
//   ReportsClient.SelectedAreas().
//
Function CellsAmount(SpreadsheetDocument, SelectedAreas) Export
	
	If SelectedAreas = Undefined Then
		#If Client Then
			SelectedAreas = SpreadsheetDocument.SelectedAreas;
		#Else
			Return NStr("en='Selected Areas parameter value is not specified.';ru='Не указано значение параметра ""ВыделенныеОбласти"".'");
		#EndIf
	EndIf;
	
	#If Client AND Not ThickClientOrdinaryApplication Then
		MarkedAreasNumber = SelectedAreas.Count();
		If MarkedAreasNumber = 0 Then
			Return ""; // There is no any number.
		ElsIf MarkedAreasNumber >= 100 Then
			Return "<"; // Server call is required.
		EndIf;
		NumberOfOutputCells = 0;
	#EndIf
	
	Amount = Undefined;
	CheckedCells = New Map;
	
	For Each SelectedArea IN SelectedAreas Do
		#If Client Then
			If TypeOf(SelectedArea) <> Type("SpreadsheetDocumentRange") Then
				Continue;
			EndIf;
		#EndIf
		
		MarkedAreaTop = SelectedArea.Top;
		SelectedAreaBottom = SelectedArea.Bottom;
		MarkedAreaLeft = SelectedArea.Left;
		MarkedAreaRight = SelectedArea.Right;
		
		If MarkedAreaTop = 0 Then
			MarkedAreaTop = 1;
		EndIf;
		
		If SelectedAreaBottom = 0 Then
			SelectedAreaBottom = SpreadsheetDocument.TableHeight;
		EndIf;
		
		If MarkedAreaLeft = 0 Then
			MarkedAreaLeft = 1;
		EndIf;
		
		If MarkedAreaRight = 0 Then
			MarkedAreaRight = SpreadsheetDocument.TableWidth;
		EndIf;
		
		If SelectedArea.AreaType = SpreadsheetDocumentCellAreaType.Columns Then
			MarkedAreaTop = SelectedArea.Bottom;
			SelectedAreaBottom = SpreadsheetDocument.TableHeight;
		EndIf;
		
		MarkedAreaHeight = SelectedAreaBottom   - MarkedAreaTop;
		MarkedAreaWidth = MarkedAreaRight - MarkedAreaLeft;
		
		#If Client AND Not ThickClientOrdinaryApplication Then
			NumberOfOutputCells = NumberOfOutputCells + MarkedAreaWidth * MarkedAreaHeight;
			If NumberOfOutputCells >= 1000 Then
				Return "<"; // Server call is required.
			EndIf;
		#EndIf
		
		For ColumnNumber = MarkedAreaLeft To MarkedAreaRight Do
			For LineNumber = MarkedAreaTop To SelectedAreaBottom Do
				Cell = SpreadsheetDocument.Area(LineNumber, ColumnNumber, LineNumber, ColumnNumber);
				If CheckedCells.Get(Cell.Name) = Undefined Then
					CheckedCells.Insert(Cell.Name, True);
				Else
					Continue;
				EndIf;
				
				If Cell.Visible = True Then
					If Cell.AreaType <> SpreadsheetDocumentCellAreaType.Columns
						AND Cell.ContainsValue AND TypeOf(Cell.Value) = Type("Number") Then
						Number = Cell.Value;
					ElsIf ValueIsFilled(Cell.Text) Then
						Number = StringFunctionsClientServer.StringToNumber(Cell.Text);
					Else
						Continue;
					EndIf;
					If TypeOf(Number) = Type("Number") Then
						If Amount = Undefined Then
							Amount = Number;
						Else
							Amount = Amount + Number;
						EndIf;
					EndIf;
				EndIf;
			EndDo;
		EndDo;
	EndDo;
	
	If Amount = Undefined Then
		Return ""; // There is no any number.
	EndIf;
	
	Return Format(Amount, "NZ=0");
	
EndFunction

#EndRegion
