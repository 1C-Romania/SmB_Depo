////////////////////////////////////////////////////////////////////////////////
// Subsystem "Additional reports and
//  data processors", procedures and functions with the reuse of return values.
// 
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

// Kinds of additional data processors publications available in the application.
Function PublicationsAvailableTypes() Export
	
	Result = New Array();
	
	Values = Metadata.Enums.AdditionalReportsAndDataProcessorsPublicationOptions.EnumValues;
	ExcludedPublicationsKinds = AdditionalReportsAndDataProcessors.UnavailablePublicationsKinds();
	
	For Each Value IN Values Do
		If ExcludedPublicationsKinds.Find(Value.Name) = Undefined Then
			Result.Add(Enums.AdditionalReportsAndDataProcessorsPublicationOptions[Value.Name]);
		EndIf;
	EndDo;
	
	Return New FixedArray(Result);
	
EndFunction

// Publication kind that should be used for conflicting additional reports and data processors.
//
// Returns:
//   EnumirationRef.AdditionalReportsAndDataProcessorsPublicationVariants
//
Function PublicationTypeForConflictProcessings() Export
	
	KindDisconnected = Enums.AdditionalReportsAndDataProcessorsPublicationOptions.Disabled;
	ViewModeDebugging = Enums.AdditionalReportsAndDataProcessorsPublicationOptions.DebugMode;
	
	AvailableKinds = PublicationsAvailableTypes();
	If AvailableKinds.Find(ViewModeDebugging) Then
		Return ViewModeDebugging;
	Else
		Return KindDisconnected;
	EndIf;
	
EndFunction

// Settings of the form for assigned object.
Function AssignedObjectFormParameters(FormFullName, FormType = Undefined) Export
	If Not AccessRight("Read", Metadata.Catalogs.AdditionalReportsAndDataProcessors) Then
		Return "";
	EndIf;
	
	Result = New Structure("ThisIsObjectForm, FormType, ParentRef, OutputPopupObjectFilling");
	
	FormMetadata = Metadata.FindByFullName(FormFullName);
	If FormMetadata = Undefined Then
		DotPosition = StrLen(FormFullName);
		While Mid(FormFullName, DotPosition, 1) <> "." Do
			DotPosition = DotPosition - 1;
		EndDo;
		ParentFullName = Left(FormFullName, DotPosition - 1);
		ParentMetadata = Metadata.FindByFullName(ParentFullName);
	Else
		ParentMetadata = FormMetadata.Parent();
	EndIf;
	If ParentMetadata = Undefined Or TypeOf(ParentMetadata) = Type("ConfigurationMetadataObject") Then
		Return "";
	EndIf;
	Result.ParentRef = CommonUse.MetadataObjectID(ParentMetadata);
	
	If FormType <> Undefined Then
		If Upper(FormType) = Upper(AdditionalReportsAndDataProcessorsClientServer.ObjectFormType()) Then
			Result.ThisIsObjectForm = True;
		ElsIf Upper(FormType) = Upper(AdditionalReportsAndDataProcessorsClientServer.FormTypeList()) Then
			Result.ThisIsObjectForm = False;
		Else
			Result.ThisIsObjectForm = (ParentMetadata.DefaultObjectForm = FormMetadata);
		EndIf;
	Else
		Result.ThisIsObjectForm = (ParentMetadata.DefaultObjectForm = FormMetadata);
	EndIf;
	
	If Result.ThisIsObjectForm Then // Object form
		Result.FormType = AdditionalReportsAndDataProcessorsClientServer.ObjectFormType();
		ParentType = Type(StrReplace(ParentMetadata.FullName(), ".", "Ref."));
		Result.OutputPopupObjectFilling = Metadata.CommonCommands.ObjectFilling.CommandParameterType.ContainsType(ParentType);
	Else // List form
		Result.FormType = AdditionalReportsAndDataProcessorsClientServer.FormTypeList();
		Result.OutputPopupObjectFilling = False;
	EndIf;
	
	Return New FixedStructure(Result);
	
EndFunction

#EndRegion
