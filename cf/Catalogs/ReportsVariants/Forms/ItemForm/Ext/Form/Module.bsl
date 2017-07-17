#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("AutoTest") Then 
		Return;
	EndIf;
	If Object.Ref.IsEmpty() Then
		OpenError = NStr("en='You can create report variant only from the report form';ru='Новый вариант отчета можно создать только из формы отчета'");
		Return;
	EndIf;
	Parameters.Property("OpenAdditionalReportFormOnOpen", OpenAdditionalReportFormOnOpen);
	If OpenAdditionalReportFormOnOpen Then
		Return;
	EndIf;
	
	Available = ?(Object.ForAuthorOnly, "1", "2");
	
	// Reading the predefined properties;
	// Filling the attributes associated with the predefined object on open.
	ReadPredefinedProperties(True);
	
	FullRightsForVariants = ReportsVariants.FullRightsForVariants();
	RightOnThisVariant = FullRightsForVariants Or Object.Author = Users.CurrentUser();
	If Not RightOnThisVariant Then
		ReadOnly = True;
		Items.SubsystemsTree.ReadOnly = True;
	EndIf;
	
	If Object.DeletionMark Then
		Items.SubsystemsTree.ReadOnly = True;
	EndIf;
	
	If Not Object.User Then
		Items.Description.ReadOnly = True;
		Items.Available.ReadOnly = True;
		Items.Author.ReadOnly = True;
		Items.Author.AutoMarkIncomplete = False;
	EndIf;
	
	ThisIsExternal = (Object.ReportType = Enums.ReportsTypes.External);
	If ThisIsExternal Then
		Items.SubsystemsTree.ReadOnly = True;
	EndIf;
	
	Items.Available.ReadOnly = Not FullRightsForVariants;
	Items.Author.ReadOnly = Not FullRightsForVariants;
	Items.TechnicalInformation.Visible = FullRightsForVariants;
	
	
	// Filling the report name for the "View" command.
	If Object.ReportType = Enums.ReportsTypes.Internal Then
		ReportName = Object.Report.Name;
	ElsIf Object.ReportType = Enums.ReportsTypes.Additional Then
		ReportName = Object.Report.ObjectName;
	Else
		ReportName = Object.Report;
	EndIf;
	
	RefillTree(False);
	
	ReportsVariants.SubsystemsTreeAddConditionalAppearance(ThisObject);
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject) // Refilling the attributes, that are automatically cleared after record object.
	If Parameters.Property("AutoTest") Then 
		Return;
	EndIf;
	If OpenAdditionalReportFormOnOpen Then 
		Return;
	EndIf;
	
	ReadPredefinedProperties(False);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	If Not IsBlankString(OpenError) Then
		If Object.Ref.IsEmpty() Then
			Cancel = True;
		Else
			ReadOnly = True;
		EndIf;
		
		ShowMessageBox(, OpenError);
	ElsIf OpenAdditionalReportFormOnOpen Then
		Cancel = True;
		
		OpenParameters = New Structure;
		OpenParameters.Insert("Variant",      Object.Ref);
		OpenParameters.Insert("Report",        Object.Report);
		OpenParameters.Insert("VariantKey", Object.VariantKey);
		ReportsVariantsClient.OpenAdditionalReportVariants(OpenParameters);
	EndIf;
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	If Source <> ThisObject AND EventName = ReportsVariantsClientServer.EventNameOptionChanging() Then
		RefillTree(True);
		Items.SubsystemsTree.Expand(SubsystemsTree.GetItems()[0].GetID(), True);
	EndIf;
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	// Record of the properties associated with the predefined report variant.
	If TypeOf(PredefinedProperties) = Type("FixedStructure") Then
		CurrentObject.VisibleByDefaultIsOverridden = 
			Object.VisibleByDefault <> PredefinedProperties.VisibleByDefault;
		
		If Not IsBlankString(Object.Definition) AND Lower(TrimAll(Object.Definition)) = Lower(TrimAll(PredefinedProperties.Definition)) Then
			CurrentObject.Definition = "";
		EndIf;
	EndIf;
	
	// Subsystems tree record.
	ReportsVariants.SubsystemsTreeWrite(ThisObject, CurrentObject);
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	RefillTree(False);
	StandardSubsystemsClientServer.CollapseTreeNodes(WriteParameters, "SubsystemsTree", "*", True);
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	NotificationParameter = New Structure("Refs, Name, Author, Description");//, VisibleByDefault);
	FillPropertyValues(NotificationParameter, Object);
	Notify(ReportsVariantsClientServer.EventNameOptionChanging(), NotificationParameter, ThisObject);
	StandardSubsystemsClient.ShowExecutionResult(ThisObject, WriteParameters);
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure DescriptionStartChoice(Item, ChoiceData, StandardProcessing)
	StandardProcessing = False;
	ReportsVariantsClient.EditMultilineText(ThisObject, Item.EditText, Object, "Definition", NStr("en='Definitions';ru='Определение'"));
EndProcedure

&AtClient
Procedure AvailableOnModification(Item)
	Object.ForAuthorOnly = (ThisObject.Available = "1");
EndProcedure

#EndRegion

#Region FormTableItemsEventsHandlersSubsystemsTree

&AtClient
Procedure SubsystemsTreeUsingOnChange(Item)
	ReportsVariantsClient.SubsystemsTreeUsingOnChange(ThisObject, Item);
EndProcedure

&AtClient
Procedure SubsystemsTreeImportanceOnChange(Item)
	ReportsVariantsClient.SubsystemsTreeImportanceOnChange(ThisObject, Item);
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Function RefillTree(Read)
	If Read Then
		ThisObject.Read();
	EndIf;
	TreeReceiver = ReportsVariants.SubsystemsTreeGenerate(ThisObject, Object);
	ValueToFormAttribute(TreeReceiver, "SubsystemsTree");
	Return True;
EndFunction

&AtServer
Procedure ReadPredefinedProperties(FirstReading)
	If FirstReading Then
		If Object.ReportType = Enums.ReportsTypes.Internal
			AND Not Object.User
			AND ValueIsFilled(Object.PredefinedVariant) Then // Reading the predefined settings.
			Query = New Query("SELECT VisibleByDefault, Definition FROM Catalog.PredefinedReportsVariants WHERE Ref = &Ref");
			Query.SetParameter("Ref", Object.PredefinedVariant);
			QueryResult = Query.Execute().Unload()[0];
			StructurePredefinedProperties = New Structure("VisibleByDefault, Definition");
			FillPropertyValues(StructurePredefinedProperties, QueryResult);
			PredefinedProperties = New FixedStructure(StructurePredefinedProperties);
		Else
			Return; // Not predefined.
		EndIf;
	Else
		If TypeOf(PredefinedProperties) <> Type("FixedStructure") Then
			Return; // Not predefined.
		EndIf;
	EndIf;
	
	If Object.VisibleByDefaultIsOverridden = False Then
		Object.VisibleByDefault = PredefinedProperties.VisibleByDefault;
	EndIf;
	
	If IsBlankString(Object.Definition) Then
		Object.Definition = PredefinedProperties.Definition;
	EndIf;
EndProcedure

#EndRegion














