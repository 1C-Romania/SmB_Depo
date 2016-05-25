&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	If Not AccessRight("DataAdministration", Metadata) Then
		Raise NStr("en = 'Insufficient rights to setup automatic REST-service'");
	EndIf;
	
	AuthorizationSettings = DataProcessors.StandardODataInterfaceSetup.AuthorizationSettingsForStandardODataInterface();
	
	CreateUserStandardInterfaceOData = AuthorizationSettings.Used;
	
	If ValueIsFilled(AuthorizationSettings.Login) Then
		
		UserName = AuthorizationSettings.Login;
		
		If CreateUserStandardInterfaceOData Then
			
			CheckingPasswordChange = String(New UUID());
			Password = CheckingPasswordChange;
			PasswordConfirmation = CheckingPasswordChange;
			
		EndIf;
		
	Else
		
		UserName = "odata.user";
		
	EndIf;
	
	If CommonUseSTLReUse.AvailableMechanismsCompatibilityMode8_3_5() Then
		
		InitializationData = DataProcessors.StandardODataInterfaceSetup.StandardODataInterfaceContentSettings();
		ValueToFormAttribute(InitializationData.ObjectsTree, "MetadataObjects");
		ValueToFormAttribute(InitializationData.AddDependencies, "DependenciesForAdd");
		ValueToFormAttribute(InitializationData.DeletionDependencies, "DependenciesToDelete");
		
	EndIf;
	
	SetVisibleAndEnabled();
	
EndProcedure

&AtServer
Procedure SetVisibleAndEnabled()
	
	Items.UserNameAndPassword.Enabled = CreateUserStandardInterfaceOData;
	Items.Content.Visible = CommonUseSTLReUse.AvailableMechanismsCompatibilityMode8_3_5();
	
EndProcedure

&AtClient
Procedure CreateUserStandardInterfaceODataOnChange(Item)
	
	SetVisibleAndEnabled();
	
EndProcedure

&AtServer
Function DependenciesForAddingObject(Val RowID)
	
	DependenciesTable = FormAttributeToValue("DependenciesForAdd");
	Return DependenciesForObject(RowID, DependenciesTable, True);
	
EndFunction

&AtServer
Function DependenciesForObjectDeletion(Val RowID)
	
	DependenciesTable = FormAttributeToValue("DependenciesToDelete");
	Return DependenciesForObject(RowID, DependenciesTable, False);
	
EndFunction

&AtServer
Function DependenciesForObject(Val RowID, DependenciesTable, UsageReference)
	
	Result = New Array();
	
	CurrentObjectName = MetadataObjects.FindByID(RowID).DescriptionFull;
	
	ObjectsTree = FormAttributeToValue("MetadataObjects");
	
	FillRequiredObjectDependenciesByString(Result, ObjectsTree, DependenciesTable, CurrentObjectName, UsageReference);
	
	Return Result;
	
EndFunction

&AtServer
Procedure FillRequiredObjectDependenciesByString(Result, ObjectsTree, DependenciesTable, CurrentObjectName, UsageReference)
	
	FilterParameters = New Structure();
	FilterParameters.Insert("ObjectName", CurrentObjectName);
	
	DependenciesStrings = DependenciesTable.FindRows(FilterParameters);
	
	For Each DependencyString IN DependenciesStrings Do
		
		DependentObjectInTree = ObjectsTree.Rows.Find(DependencyString.DependentObjectName, "DescriptionFull", True);
		
		If DependentObjectInTree.Use <> UsageReference AND Result.Find(DependencyString.DependentObjectName) = Undefined Then
			
			Result.Add(DependencyString.DependentObjectName);
			FillRequiredObjectDependenciesByString(Result, ObjectsTree, DependenciesTable, 
				DependencyString.DependentObjectName, UsageReference);
			
		EndIf;
		
	EndDo;
	
EndProcedure

&AtClient
Procedure MetadataObjectsUseOnChange(Item)
	
	If Items.MetadataObjects.CurrentData.Use Then
		
		Insert = True;
		Dependencies = DependenciesForAddingObject(Items.MetadataObjects.CurrentData.GetID());
		
	Else
		
		Insert = False;
		Dependencies = DependenciesForObjectDeletion(Items.MetadataObjects.CurrentData.GetID());
		
	EndIf;
	
	If Dependencies.Count() > 0 Then
		
		FormParameters = New Structure();
		FormParameters.Insert("FullObjectName", Items.MetadataObjects.CurrentData.DescriptionFull);
		FormParameters.Insert("ObjectDependencies", Dependencies);
		FormParameters.Insert("Insert", Insert);
		
		Context = New Structure();
		Context.Insert("Dependencies", Dependencies);
		Context.Insert("Insert", Insert);
		
		Callback = New NotifyDescription("MetadataObjectsUseOnChangingContinuation", ThisObject, Context);
		
		OpenForm(
			"DataProcessor.StandardODataInterfaceSetup.Form.MetadataObjectDependence",
			FormParameters,
			,
			,
			,
			,
			Callback,
			FormWindowOpeningMode.LockOwnerWindow);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure SetDependenciesUse(Val Dependencies, Val Usage)
	
	RootItems = MetadataObjects.GetItems();
	
	For Each RootElement IN RootItems Do
		
		TreeItems = RootElement.GetItems();
		
		For Each TreeItem IN TreeItems Do
			
			If Dependencies.Find(TreeItem.DescriptionFull) <> Undefined Then
				
				TreeItem.Use = Usage;
				
			EndIf;
			
		EndDo;
		
	EndDo;
	
EndProcedure

&AtClient
Procedure MetadataObjectsUseOnChangingContinuation(Result, Context) Export
	
	If Result = DialogReturnCode.Yes Then
		
		SetDependenciesUse(Context.Dependencies, Context.Insert);
		
	Else
		
		Items.MetadataObjects.CurrentData.Use = Not Items.MetadataObjects.CurrentData.Use;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	If CreateUserStandardInterfaceOData Then
		
		If Not ValueIsFilled(UserName) Then
			CommonUseClientServer.MessageToUser(NStr("en = 'User name is not specified'"), , "UserName");
			Cancel = True;
		EndIf;
		
		If Not ValueIsFilled(Password) Then
			CommonUseClientServer.MessageToUser(NStr("en = 'Password is not specified'"), , "Password");
			Cancel = True;
		EndIf;
		
		If Not ValueIsFilled(PasswordConfirmation) Then
			CommonUseClientServer.MessageToUser(NStr("en = 'Password confirmation is not indicated'"), , "PasswordConfirmation");
			Cancel = True;
		EndIf;
		
		If ValueIsFilled(Password) AND ValueIsFilled(PasswordConfirmation) AND Password <> PasswordConfirmation Then
			CommonUseClientServer.MessageToUser(NStr("en = 'Password confirmation does not match password'"), , "PasswordConfirmation");
			Cancel = True;
		EndIf;
		
	EndIf;
	
	If CommonUseSTLReUse.AvailableMechanismsCompatibilityMode8_3_5() Then
		
		Tree = FormAttributeToValue("MetadataObjects");
		RowFilter = New Structure();
		RowFilter.Insert("Use", True);
		Rows = Tree.Rows.FindRows(RowFilter, True);
		If Rows.Count() = 0 Then
			CommonUseClientServer.MessageToUser(NStr("en = 'No object is selected to which the access is allowed through automatic REST-service'"), , "MetadataObjects");
			Cancel = True;
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Function Save(Command = Undefined)
	
	If Modified Then
		
		If CheckFilling() Then
			
			SaveOnServer();
			Return True;
			
		Else
			
			Return False;
			
		EndIf;
		
	Else
		
		Return True;
		
	EndIf;
	
EndFunction

&AtServer
Procedure SaveOnServer()
	
	BeginTransaction();
	
	Try
		
		Settings = New Structure();
		
		Settings.Insert("Used", CreateUserStandardInterfaceOData);
		Settings.Insert("Login", UserName);
		
		If Password = PasswordConfirmation Then
			
			If Password <> CheckingPasswordChange Then
				Settings.Insert("Password", Password);
			EndIf;
			
		Else
			
			Raise NStr("en = 'Password and password confirmation do not match!'");
			
		EndIf;
		
		DataProcessors.StandardODataInterfaceSetup.WriteAuthorizationSettingsForStandardODataInterface(Settings);
		
		If CommonUseSTLReUse.AvailableMechanismsCompatibilityMode8_3_5() Then
			
			Content = New Array();
			
			Tree = FormAttributeToValue("MetadataObjects");
			Rows = Tree.Rows.FindRows(New Structure("Use", True), True);
			For Each String IN Rows Do
				Content.Add(String.DescriptionFull);
			EndDo;
			
			WorkInSafeMode.ExecuteInSafeMode("SetStandardInterfaceContentOData(Parameters);", Content);
			
		EndIf;
		
		CommitTransaction();
		
		Modified = False;
		
	Except
		
		RollbackTransaction();
		Raise;
		
	EndTry;
	
EndProcedure

&AtClient
Procedure SaveAndClose(Command = Undefined)
	
	If Save() Then
		Close();
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	If Modified Then
		
		Cancel = True;
		
		Callback = New NotifyDescription("ContinueClosingAfterQuestion", ThisObject);
		ShowQueryBox(Callback, NStr("en = 'Data was changed. Save changes?'"), QuestionDialogMode.YesNoCancel);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ContinueClosingAfterDoQueryBox(Result, Context) Export
	
	If Result = DialogReturnCode.Yes Then
		
		SaveAndClose();
		
	ElsIf Result = DialogReturnCode.No Then
		
		Modified = False;
		Close();
		
	EndIf;
	
EndProcedure












// Rise { Popov N 2016-05-25
&AtClient
Function RiseGetFormInterfaceClient() Export
	Return RiseGetFormInterface();
EndFunction

&AtServer
Function RiseGetFormInterface()
	Return RiseTranslation.GetFormInterface(ThisForm);
EndFunction
// Rise } Popov N 2016-05-25
