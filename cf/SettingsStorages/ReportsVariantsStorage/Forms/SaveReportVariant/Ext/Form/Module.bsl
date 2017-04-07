#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	SetConditionalAppearance();
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	Context = New Structure;
	Context.Insert("CurrentUser", Users.CurrentUser());
	Context.Insert("FullRightsForVariants", ReportsVariants.FullRightsForVariants());
	Context.Insert("CurrentStringID", 0);
	
	PrototypeKey = Parameters.CurrentSettingsKey;
	
	ReportInformation = ReportsVariants.GenerateInformationAboutReportByDescriptionFull(Parameters.ObjectKey);
	If TypeOf(ReportInformation.ErrorText) = Type("String") Then
		Raise ReportInformation.ErrorText;
	EndIf;
	Context.Insert("ReportRef", ReportInformation.Report);
	Context.Insert("ReportName",    ReportInformation.ReportName);
	Context.Insert("ReportType",   ReportInformation.ReportType);
	Context.Insert("ThisIsExternal",  ReportInformation.ReportType = Enums.ReportsTypes.External);
	
	FillVariantsList();
	
	ReportsVariants.SubsystemsTreeAddConditionalAppearance(ThisObject);
	
	If Not Context.FullRightsForVariants Then
		Items.GroupAvailable.ReadOnly = True;
	EndIf;
	
	If Context.ThisIsExternal Then
		Items.ExternalReportDescription.Visible = True;
		Items.VariantVisibleByDefault.Visible = False;
		Items.Back.Visible = False;
		Items.GoToNext.Visible = False;
		Items.DecorationNext.Visible = False;
	EndIf;
	
	ReportVariantsStringOnActivateHandler(ThisObject);
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	If Not ValueIsFilled(OptionName) Then
		CommonUseClientServer.MessageToUser(
			NStr("en='Field ""Description"" is not filled out';ru='Поле ""Наименование"" не заполнено'"),
			,
			"Description");
		Cancel = True;
	ElsIf ReportsVariants.DescriptionIsBooked(Context.ReportRef, VariantRef, OptionName) Then
		CommonUseClientServer.MessageToUser(
			StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='""%1"" is occupied, you must specify another Description.';ru='""%1"" занято, необходимо указать другое Наименование.'"),
				OptionName
			),
			,
			"Description");
		Cancel = True;
	EndIf;
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	If Source = FormName Then
		Return;
	EndIf;
	
	If EventName = ReportsVariantsClientServer.EventNameOptionChanging()
		AND TypeOf(Parameter) = Type("Structure")
		AND Parameter.Property("Ref") Then
		
		Found = ReportVariants.FindRows(New Structure("Ref", Parameter.Ref));
		If Found.Count() = 1 Then
			Variant = Found[0];
			FillPropertyValues(Variant, Parameter);
			Variant.AuthorCurrentUser = (Variant.Author = Context.CurrentUser);
			ReportVariantsStringOnActivateHandler(ThisObject);
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	CurrentItem = Items.Description;
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure DescriptionOnChange(Item)
	Found = ReportVariants.FindRows(New Structure("Description", OptionName));
	If Found.Count() > 0 Then
		Items.ReportVariants.CurrentRow = Found[0].GetID();
		ReportVariantsStringOnActivateHandler(ThisObject);
	Else
		VariantRef = Undefined;
		SetWhatGoesNext(ThisObject, False);
	EndIf;
EndProcedure

&AtClient
Procedure NameAutoFilter(Item, Text, ChoiceData, Wait, StandardProcessing)
	Found = ReportVariants.FindRows(New Structure("Description", Text));
	SetWhatGoesNext(ThisObject, Found.Count() > 0);
EndProcedure

&AtClient
Procedure AvailableOnModification(Item)
	VariantOnlyForAuthor = (Available = "1");
EndProcedure

&AtClient
Procedure DescriptionStartChoice(Item, ChoiceData, StandardProcessing)
	StandardProcessing = False;
	Notification = New NotifyDescription("DescriptionStartChoiceEnd", ThisObject);
	CommonUseClient.ShowMultilineTextEditingForm(Notification, Items.Definition.EditText,
		NStr("en='Definition';ru='Определение'"));
EndProcedure

#EndRegion

#Region FormTableItemEventHandlersReportVariants

&AtClient
Procedure ReportVariantsOnActivateRow(Item)
	If Context.CurrentStringID = Items.ReportVariants.CurrentRow Then
		Return;
	EndIf;
	ReportVariantsStringOnActivateHandler(ThisObject);
EndProcedure

&AtClient
Procedure ReportVariantsSelection(Item, SelectedRow, Field, StandardProcessing)
	StandardProcessing = False;
	SaveAndClose();
EndProcedure

&AtClient
Procedure ReportVariantsBeforeModification(Item, Cancel)
	Cancel = True;
	OpenVariantForModification();
EndProcedure

&AtClient
Procedure VariantsOfReportBeforeDelition(Item, Cancel)
	Cancel = True;
	Variant = Items.ReportVariants.CurrentData;
	If Variant = Undefined OR Not ValueIsFilled(Variant.Ref) Then
		Return;
	EndIf;
	
	If Not Context.FullRightsForVariants AND Not Variant.AuthorCurrentUser Then
		WarningText = NStr("en='The access rights are not sufficient to delete the report variant ""%1"".';ru='Недостаточно прав доступа для удаления варианта отчета ""%1"".'");
		WarningText = StrReplace(WarningText, "%1", Variant.Description);
		ShowMessageBox(, WarningText);
		Return;
	EndIf;
	
	If Not Variant.User Then
		ShowMessageBox(, NStr("en='Impossible to delete the predefined report variant.';ru='Невозможно удалить предопределенный вариант отчета.'"));
		Return;
	EndIf;
	
	If Variant.DeletionMark Then
		QuestionText = NStr("en='Unmark ""%1"" for deletion?';ru='Снять с ""%1"" пометку на удаление?'");
	Else
		QuestionText = NStr("en='Mark ""%1"" for deletion?';ru='Пометить ""%1"" на удаление?'");
	EndIf;
	QuestionText = StrReplace(QuestionText, "%1", Variant.Description);
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("Variant", Variant);
	Handler = New NotifyDescription("ReportVariantsBeforeDelitionEnd", ThisObject, AdditionalParameters);
	
	ShowQueryBox(Handler, QuestionText, QuestionDialogMode.YesNo, 60, DialogReturnCode.Yes); 
EndProcedure

&AtClient
Procedure ReportVariantsBeforeCreation(Item, Cancel, Copy, Parent, Group)
	Cancel = True;
EndProcedure

#EndRegion

#Region FormTableItemEventHandlersSubsystemTree

&AtClient
Procedure SubsystemsTreeUsingOnChange(Item)
	ReportsVariantsClient.SubsystemsTreeUsingOnChange(ThisObject, Item);
EndProcedure

&AtClient
Procedure SubsystemsTreeImportanceOnChange(Item)
	ReportsVariantsClient.SubsystemsTreeImportanceOnChange(ThisObject, Item);
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure Back(Command)
	GoToPage1();
EndProcedure

&AtClient
Procedure GoToNext(Command)
	Package = New Structure;
	Package.Insert("CheckPage1",       True);
	Package.Insert("GoToPage2",       True);
	Package.Insert("FillPage2Server", True);
	Package.Insert("CheckAndWriteServer", False);
	Package.Insert("CloseAfterWriting",       False);
	Package.Insert("CurrentStep", Undefined);
	
	ExecuteBatch(Undefined, Package);
EndProcedure

&AtClient
Procedure Save(Command)
	SaveAndClose();
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure SetConditionalAppearance()
	Instruction = ReportsVariants.ConditionalDesignInstruction();
	Instruction.Fields = "ReportVariants, ReportVariantsDescription";
	Instruction.Filters.Insert("ReportsVariants.User", False);
	Instruction.Appearance.Insert("TextColor", StyleColors.HiddenReportOptionColor);
	ReportsVariants.AddConditionalAppearanceItem(ThisObject, Instruction);
	
	Instruction = ReportsVariants.ConditionalDesignInstruction();
	Instruction.Fields = "ReportVariants, ReportVariantsDescription";
	Instruction.Filters.Insert("FullRightsForVariants", False);
	Instruction.Filters.Insert("ReportsVariants.AuthorCurrentUser", False);
	Instruction.Appearance.Insert("TextColor", StyleColors.HiddenReportOptionColor);
	ReportsVariants.AddConditionalAppearanceItem(ThisObject, Instruction);
	
	Instruction = ReportsVariants.ConditionalDesignInstruction();
	Instruction.Fields = "ReportVariants, ReportVariantsDescription";
	Instruction.Filters.Insert("ReportsVariants.Order", 3);
	Instruction.Appearance.Insert("TextColor", StyleColors.HiddenReportOptionColor);
	ReportsVariants.AddConditionalAppearanceItem(ThisObject, Instruction);
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Client

&AtClient
Procedure ExecuteBatch(Result, Package) Export
	If Not Package.Property("VariantIsNew") Then
		Package.Insert("VariantIsNew", Not ValueIsFilled(VariantRef));
	EndIf;
	
	// Processing the result of the previous step.
	If Package.CurrentStep = "QueryOnRewriting" Then
		Package.CurrentStep = Undefined;
		If Result = DialogReturnCode.Yes Then
			Package.Insert("QueryOnRewritingIsPassed", True);
		Else
			Return;
		EndIf;
	EndIf;
	
	// Execution next step.
	If Package.CheckPage1 = True Then
		// Description is not entered.
		If Not ValueIsFilled(OptionName) Then
			ErrorText = NStr("en='Field ""Description"" is not filled out';ru='Поле ""Наименование"" не заполнено'");
			CommonUseClientServer.MessageToUser(ErrorText, , "OptionName");
			Return;
		EndIf;
		
		// Description of existing report variant is entered.
		If Not Package.VariantIsNew Then
			Found = ReportVariants.FindRows(New Structure("Ref", VariantRef));
			Variant = Found[0];
			If Not RightVariantModification(Variant, RightVariantSettings(Variant, Context.FullRightsForVariants)) Then
				ErrorText = NStr("en='The rights are not sufficient to change the variant ""%1"", it is necessary to select another variant or change the Description.';ru='Недостаточно прав для изменения варианта ""%1"", необходимо выбрать другой вариант или изменить Наименование.'");
				ErrorText = StringFunctionsClientServer.SubstituteParametersInString(ErrorText, OptionName);
				CommonUseClientServer.MessageToUser(ErrorText, , "OptionName");
				Return;
			EndIf;
			
			If Not Package.Property("QueryOnRewritingIsPassed") Then
				If Variant.DeletionMark = True Then
					QuestionText = NStr("en='Report variant ""%1"" is marked to delete.
		|Do you want to replace the marked for deletion report variant?';ru='Вариант отчета ""%1"" помечен на удаление.
		|Заменить помеченный на удаление вариант отчета?'");
					DefaultButton = DialogReturnCode.No;
				Else
					QuestionText = NStr("en='Replace previously saved report variant ""%1""?';ru='Заменить ранее сохраненный вариант отчета ""%1""?'");
					DefaultButton = DialogReturnCode.Yes;
				EndIf;
				QuestionText = StringFunctionsClientServer.SubstituteParametersInString(QuestionText, OptionName);
				Package.CurrentStep = "QueryOnRewriting";
				Handler = New NotifyDescription("ExecuteBatch", ThisObject, Package);
				ShowQueryBox(Handler, QuestionText, QuestionDialogMode.YesNo, 60, DefaultButton);
				Return;
			EndIf;
		EndIf;
		
		// Check is completed.
		Package.CheckPage1 = False;
	EndIf;
	
	If Package.GoToPage2 = True Then
		// For external reports only the checks of filling are executed, without going to the next page.
		If Not Context.ThisIsExternal Then
			Items.Pages.CurrentPage = Items.Page2;
			Items.Back.Enabled        = True;
			Items.GoToNext.Enabled        = False;
		EndIf;
		
		// Switch is completed.
		Package.GoToPage2 = False;
	EndIf;
	
	If Package.FillPage2Server = True
		Or Package.CheckAndWriteServer = True Then
		
		ExecuteBatchServer(Package);
		
		TreeRows = SubsystemsTree.GetItems();
		For Each TreeRow IN TreeRows Do
			Items.SubsystemsTree.Expand(TreeRow.GetID(), True);
		EndDo;
		
		If Package.Cancel = True Then
			GoToPage1();
			Return;
		EndIf;
		
	EndIf;
	
	If Package.CloseAfterWriting = True Then
		ReportsVariantsClient.OpenFormsRefresh(, FormName);
		Close(New SettingsChoice(VariantVariantKey));
		Package.CloseAfterWriting = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure GoToPage1()
	Items.Pages.CurrentPage = Items.Page1;
	Items.Back.Enabled        = False;
	Items.GoToNext.Title          = "";
	Items.GoToNext.Enabled        = True;
EndProcedure

&AtClient
Procedure OpenVariantForModification()
	Variant = Items.ReportVariants.CurrentData;
	If Variant = Undefined OR Not ValueIsFilled(Variant.Ref) Then
		Return;
	EndIf;
	If Not RightVariantSettings(Variant, Context.FullRightsForVariants) Then
		WarningText = NStr("en='The access rights are not sufficient to change the variant ""%1"".';ru='Недостаточно прав доступа для изменения варианта ""%1"".'");
		WarningText = StringFunctionsClientServer.SubstituteParametersInString(WarningText, Variant.Description);
		ShowMessageBox(, WarningText);
		Return;
	EndIf;
	ShowValue(, Variant.Ref);
EndProcedure

&AtClient
Procedure SaveAndClose()
	Page2IsFull = (Items.Pages.CurrentPage = Items.Page2);
	
	Package = New Structure;
	Package.Insert("CheckPage1",       Not Page2IsFull);
	Package.Insert("GoToPage2",       Not Page2IsFull);
	Package.Insert("FillPage2Server", Not Page2IsFull);
	Package.Insert("CheckAndWriteServer", True);
	Package.Insert("CloseAfterWriting",       True);
	Package.Insert("CurrentStep", Undefined);
	
	ExecuteBatch(Undefined, Package);
EndProcedure

&AtClient
Procedure DescriptionStartChoiceEnd(Val EnteredText, Val AdditionalParameters) Export
	
	If EnteredText = Undefined Then
		Return;
	EndIf;	

	VariantDescription = EnteredText;
	
EndProcedure

&AtClient
Procedure ReportVariantsBeforeDelitionEnd(Response, AdditionalParameters) Export
	If Response = DialogReturnCode.Yes Then
		Variant = AdditionalParameters.Variant;
		DeleteVariantOnServer(Variant.Ref, Variant.PictureIndex, Variant.DeletionMark);
		ReportVariantsStringOnActivateHandler(ThisObject);
	EndIf;
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Client and server

&AtClientAtServerNoContext
Procedure ReportVariantsStringOnActivateHandler(Form)
	Form.Context.CurrentStringID = Form.Items.ReportVariants.CurrentRow;
	If Form.Context.CurrentStringID = Undefined Then
		Return;
	EndIf;
	
	Variant = Form.ReportVariants.FindByID(Form.Context.CurrentStringID);
	If Variant = Undefined Then
		Return;
	EndIf;
	
	RightVariantSettings = RightVariantSettings(Variant, Form.Context.FullRightsForVariants);
	RightVariantModification    = RightVariantModification(Variant, RightVariantSettings);
	If RightVariantModification Then
		Form.VariantRef = Variant.Ref;
		Form.VariantAuthor  = Variant.Author;
		Form.OptionName = Variant.Description;
		Form.VariantDescription     = Variant.Definition;
		Form.VariantOnlyForAuthor      = Variant.ForAuthorOnly;
		Form.VariantVisibleByDefault = Variant.VisibleByDefault;
	Else
		Form.VariantRef = Undefined;
		Form.VariantAuthor  = Form.Context.CurrentUser;
		Form.OptionName = GenerateFreeName(Variant, Form.ReportVariants);
		Form.VariantDescription     = "";
		Form.VariantOnlyForAuthor      = True;
		Form.VariantVisibleByDefault = True;
	EndIf;
	
	Form.Available = ?(Form.VariantOnlyForAuthor, "1", "2");
	
	SetWhatGoesNext(Form, ValueIsFilled(Form.VariantRef));
EndProcedure

&AtClientAtServerNoContext
Function RightVariantSettings(Variant, FullRightsForVariants)
	Return (FullRightsForVariants OR Variant.AuthorCurrentUser) AND ValueIsFilled(Variant.Ref);
EndFunction

&AtClientAtServerNoContext
Function RightVariantModification(Variant, RightVariantSettings)
	Return Variant.User AND RightVariantSettings;
EndFunction

&AtClientAtServerNoContext
Function GenerateFreeName(Variant, ReportVariants)
	VariantNameTemplate = TrimAll(Variant.Description) +" - "+ NStr("en='copy';ru='копия'");
	
	FreeName = VariantNameTemplate;
	Found = ReportVariants.FindRows(New Structure("Description", FreeName));
	If Found.Count() = 0 Then
		Return FreeName;
	EndIf;
	
	VariantNumber = 1;
	While True Do
		VariantNumber = VariantNumber + 1;
		FreeName = VariantNameTemplate +" (" + Format(VariantNumber, "") + ")";
		Found = ReportVariants.FindRows(New Structure("Description", FreeName));
		If Found.Count() = 0 Then
			Return FreeName;
		EndIf;
	EndDo;
EndFunction

&AtClientAtServerNoContext
Procedure SetWhatGoesNext(Form, Overwriting)
	If Overwriting Then
		Form.Items.OverwritingOrNew.CurrentPage = Form.Items.Overwriting;
	Else
		Form.Items.OverwritingOrNew.CurrentPage = Form.Items.New;
	EndIf;
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Calling the server

&AtServer
Procedure ExecuteBatchServer(Package)
	
	Package.Insert("Cancel", False);
	
	If Package.FillPage2Server = True Then
		If Not Context.ThisIsExternal Then
			RefillSecondPage(Package);
		EndIf;
		Package.FillPage2Server = False;
	EndIf;
	
	If Package.CheckAndWriteServer = True Then
		CheckAndWriteOnServer(Package);
		Package.CheckAndWriteServer = False;
	EndIf;
	
EndProcedure

&AtServerNoContext
Procedure DeleteVariantOnServer(Ref, PictureIndex, DeletionMark)
	VariantObject = Ref.GetObject();
	VariantObject.SetDeletionMark(NOT VariantObject.DeletionMark);
	DeletionMark = VariantObject.DeletionMark;
	PictureIndex = ?(DeletionMark, 4, ?(VariantObject.User, 3, 5));
EndProcedure

&AtServer
Procedure RefillSecondPage(Package)
	If Package.VariantIsNew Then
		OptionBasis = PrototypeRef;
	Else
		OptionBasis = VariantRef;
	EndIf;
	
	TreeReceiver = ReportsVariants.SubsystemsTreeGenerate(ThisObject, OptionBasis);
	ValueToFormAttribute(TreeReceiver, "SubsystemsTree");
EndProcedure

&AtServer
Procedure CheckAndWriteOnServer(Package)
	VariantIsNew = Not ValueIsFilled(VariantRef);
	
	If VariantIsNew AND ReportsVariants.DescriptionIsBooked(Context.ReportRef, VariantRef, OptionName) Then
		ErrorText = NStr("en='""%1"" is occupied, you must specify another Description.';ru='""%1"" занято, необходимо указать другое Наименование.'");
		ErrorText = StringFunctionsClientServer.SubstituteParametersInString(ErrorText, OptionName);
		CommonUseClientServer.MessageToUser(ErrorText, , "OptionName");
		Package.Cancel = True;
		Return;
	EndIf;
	
	If VariantIsNew Then
		VariantObject = Catalogs.ReportsVariants.CreateItem();
		VariantObject.Report            = Context.ReportRef;
		VariantObject.ReportType        = Context.ReportType;
		VariantObject.VariantKey     = String(New UUID());
		VariantObject.User = True;
		VariantObject.Author            = Context.CurrentUser;
		VariantObject.FillParent();
	Else
		VariantObject = VariantRef.GetObject();
	EndIf;
	
	If Context.ThisIsExternal Then
		VariantObject.Placement.Clear();
	Else
		ReportsVariants.SubsystemsTreeWrite(ThisObject, VariantObject);
	EndIf;
	
	VariantObject.Description = OptionName;
	VariantObject.Definition     = VariantDescription;
	VariantObject.ForAuthorOnly      = VariantOnlyForAuthor;
	VariantObject.VisibleByDefault = VariantVisibleByDefault;
	
	VariantObject.Write();
	
	VariantRef       = VariantObject.Ref;
	VariantVariantKey = VariantObject.VariantKey;
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Server

&AtServer
Procedure FillVariantsList()
	
	CurrentVariantKey = PrototypeKey;
	If ValueIsFilled(Items.ReportVariants.CurrentRow) Then
		CurrentRow = ReportVariants.FindByID(Items.ReportVariants.CurrentRow);
		If ValueIsFilled(CurrentRow.VariantKey) Then
			CurrentVariantKey = CurrentRow.VariantKey;
		EndIf;
	EndIf;
	
	ReportVariants.Clear();
	
	QueryText =
	"SELECT ALLOWED
	|	ReportsVariants.Ref AS Ref,
	|	ReportsVariants.User AS User,
	|	ReportsVariants.Description AS Description,
	|	ReportsVariants.Author AS Author,
	|	ReportsVariants.Definition AS Definition,
	|	ReportsVariants.ReportType AS Type,
	|	ReportsVariants.VariantKey AS VariantKey,
	|	ReportsVariants.ForAuthorOnly AS ForAuthorOnly,
	|	ReportsVariants.VisibleByDefault AS VisibleByDefault,
	|	ReportsVariants.DeletionMark AS DeletionMark,
	|	CASE
	|		WHEN ReportsVariants.Author = &CurrentUser
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS AuthorCurrentUser,
	|	CASE
	|		WHEN ReportsVariants.DeletionMark
	|			THEN 4
	|		WHEN ReportsVariants.User
	|			THEN 3
	|		ELSE 5
	|	END AS PictureIndex,
	|	CASE
	|		WHEN ReportsVariants.DeletionMark
	|			THEN 3
	|		WHEN ReportsVariants.User
	|			THEN 2
	|		ELSE 1
	|	END AS Order
	|FROM
	|	Catalog.ReportsVariants AS ReportsVariants
	|WHERE
	|	ReportsVariants.Report = &Report
	|	AND (ReportsVariants.DeletionMark = FALSE
	|			OR ReportsVariants.User = TRUE)
	|	AND (ReportsVariants.ForAuthorOnly = FALSE
	|			OR ReportsVariants.Author = &CurrentUser
	|			OR ReportsVariants.VariantKey = &CurrentVariantKey)
	|	AND Not ReportsVariants.PredefinedVariant IN (&DisabledApplicationOptions)";
	
	Query = New Query;
	Query.SetParameter("Report", Context.ReportRef);
	Query.SetParameter("CurrentVariantKey", CurrentVariantKey);
	Query.SetParameter("CurrentUser", Context.CurrentUser);
	Query.SetParameter("DisabledApplicationOptions", ReportsVariantsReUse.DisabledApplicationOptions());
	
	Query.Text = QueryText;
	
	ValueTable = Query.Execute().Unload();
	
	ReportVariants.Load(ValueTable);
	
	// Add predefined variant of external report.
	If Context.ThisIsExternal Then
		Try
			ReportObject = ExternalReports.Create(Context.ReportName);
		Except
			ReportsVariants.ErrorByVariant(Undefined,
				StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en='Failed to receive a predefined
		|variants list of the external report ""%1"":';ru='Не удалось получить
		|список предопределенных вариантов внешнего отчета ""%1"":'"),
					Context.ReportRef
				) + Chars.LF + DetailErrorDescription(ErrorInfo()));
			Return;
		EndTry;
		
		If ReportObject.DataCompositionSchema = Undefined Then
			Return;
		EndIf;
		
		For Each DCSettingsVariant IN ReportObject.DataCompositionSchema.SettingVariants Do
			Variant = ReportVariants.Add();
			Variant.User = False;
			Variant.Description = DCSettingsVariant.Presentation;
			Variant.VariantKey = DCSettingsVariant.Name;
			Variant.ForAuthorOnly = False;
			Variant.AuthorCurrentUser = False;
			Variant.PictureIndex = 5;
		EndDo;
	EndIf;
	
	ReportVariants.Sort("Description Asc");
	
	Context.CurrentStringID = -1;
	Found = ReportVariants.FindRows(New Structure("VariantKey", CurrentVariantKey));
	If Found.Count() > 0 Then
		Variant = Found[0];
		PrototypeRef = Variant.Ref;
		VariantDescription = Variant.Definition;
		Context.CurrentStringID = Variant.GetID();
		Items.ReportVariants.CurrentRow = Context.CurrentStringID;
	EndIf;
	
EndProcedure

#EndRegion
