#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region LocalVariables

Var UnspecifiedUserCurrentIdentifier;
Var UnspecifiedUserInitialIdentifier;
Var SavedRefsToUnspecifiedUser;

#EndRegion

#Region ServiceProgramInterface

#Region DataExportHandlers

Procedure BeforeDataExport(Container) Export
	
	UnspecifiedUserCurrentIdentifier = UsersService.CreateUnspecifiedUser().UUID();
	
	FileName = Container.CreateRandomFile("xml", UnspecifiedUserIdentifierDataExportType());
	DataExportImportService.WriteObjectToFile(UnspecifiedUserCurrentIdentifier, FileName);
	
EndProcedure

//Called before
// exporting the object. see "OnRegisteringDataExportHandlers"
//
Procedure BeforeObjectExport(Container, ObjectExportManager, Serializer, Object, Artifacts, Cancel) Export
	
	If TypeOf(Object) = Type("CatalogObject.Users") Then
		
		If Object.Ref.UUID() = UnspecifiedUserCurrentIdentifier Then
			
			NewArtifact = XDTOFactory.Create(ArtifactTypeUnspecifiedUser());
			Artifacts.Add(NewArtifact);
			
		ElsIf UsersServiceSaaSSTL.UserRegisteredAsUnseparated(Object.InfobaseUserID) Then
			
			NewArtifact = XDTOFactory.Create(TypeArtifactUnseparatedUser());
			NewArtifact.UserName = UnseparatedUserInternalName(Object.InfobaseUserID);
			Artifacts.Add(NewArtifact);
			
		EndIf;
		
	Else
		
		Raise StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='Metadata object %1 can not be processed by handler ServiceUsersInBTCSaaS.BeforeObjectExport().';ru='Объект метаданных %1 не может быть обработан обработчиком ПользователиСлужебныйВМоделиСервисаБТС.ПередВыгрузкойОбъекта()!'"),
			Object.Metadata().FullName());
		
	EndIf;
	
EndProcedure

Procedure AfterObjectExport(Container, ObjectExportManager, Serializer, Object, Artifacts) Export
	
	If TypeOf(Object) = Type("CatalogObject.Users") Then
		
		If Object.Ref.UUID() <> UnspecifiedUserCurrentIdentifier Then
			
			UnseparatedUserReference = UsersServiceSaaSSTL.UserRegisteredAsUnseparated(
				Object.InfobaseUserID);
			
			NaturalKey = New Structure("Undistributed", UnseparatedUserReference);
			ObjectExportManager.RequireMatchRefOnImport(Object.Ref, NaturalKey);
			
		EndIf;
		
	Else
		
		Raise StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='Metadata object %1 can not be processed by handler ServiceUsersInBTCSaaS.BeforeObjectExport().';ru='Объект метаданных %1 не может быть обработан обработчиком ПользователиСлужебныйВМоделиСервисаБТС.ПередВыгрузкойОбъекта()!'"),
			Object.Metadata().FullName());
		
	EndIf;
	
EndProcedure

#EndRegion

#Region DataImportHandlers

// Called before data import.
//
// Parameters:
//  Container - DataProcessorObject.DataExportImportContainerManager - manager
//    of a container that is used in the data import process. For more information, see a comment to the DataExportImportContainerManager application interface processor.
//
Procedure BeforeDataImport(Container) Export
	
	UnspecifiedUserCurrentIdentifier = UsersService.CreateUnspecifiedUser().UUID();
	
	FileName = Container.GetRandomFile(UnspecifiedUserIdentifierDataExportType());
	UnspecifiedUserInitialIdentifier = DataExportImportService.ReadObjectFromFile(FileName);
	
EndProcedure

Procedure BeforeMatchRefs(Container, MetadataObject, SourceRefsTable, StandardProcessing, Cancel) Export
	
	If MetadataObject = Metadata.Catalogs.Users Then
		
		StandardProcessing = False;
		
	Else
		
		Raise NStr("en='Invalid data type';ru='Тип данных указан неверно'");
		
	EndIf;
	
EndProcedure

Function MatchRefs(Container, RefsMappingManager, SourceRefsTable) Export
	
	ColumnName = RefsMappingManager.SourceRefsColumnName();
	
	Result = New ValueTable();
	Result.Columns.Add(ColumnName, New TypeDescription("CatalogRef.Users"));
	Result.Columns.Add("Ref", New TypeDescription("CatalogRef.Users"));
	
	MappingUnspecifiedUser = Result.Add();
	MappingUnspecifiedUser[ColumnName] =
		Catalogs.Users.GetRef(UnspecifiedUserInitialIdentifier);
	MappingUnspecifiedUser.Ref =
		Catalogs.Users.GetRef(UnspecifiedUserCurrentIdentifier);
	
	GroupUnseparatedUsers = False;
	GroupSeparatedUsers = False;
	
	If CommonUseReUse.DataSeparationEnabled() Then
		
		If Container.ExportParameters().Property("MinimizeSeparatedUsers") Then
			
			GroupSeparatedUsers = Container.ExportParameters().MinimizeSeparatedUsers;
			
		Else
			
			GroupSeparatedUsers = False;
			
		EndIf;
		
	Else
		GroupUnseparatedUsers = True;
		GroupSeparatedUsers = False;
	EndIf;
	
	For Each TableRowSourceLinks IN SourceRefsTable Do
		
		If TableRowSourceLinks.Undistributed Then
			
			If GroupUnseparatedUsers Then
				
				MappingUser = Result.Add();
				MappingUser[ColumnName] = TableRowSourceLinks[ColumnName];
				MappingUser.Ref =
					Catalogs.Users.GetRef(UnspecifiedUserCurrentIdentifier);
				
			EndIf;
			
		Else
			
			If GroupSeparatedUsers Then
				
				MappingUser = Result.Add();
				MappingUser[ColumnName] = TableRowSourceLinks[ColumnName];
				MappingUser.Ref =
					Catalogs.Users.GetRef(UnspecifiedUserCurrentIdentifier);
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	Return Result;
	
EndFunction

// Executes handlers before importing a specific data type.
//
// Parameters:
// Container - DataProcessorObject.DataExportImportContainerManager - container manager that is used in the process of data export. For more information, see a comment to the DataExportImportContainerManager application interface processor.
// MetadataObject - MetadataObject - Metadata object.
// Cancel - Boolean - Shows that the operation is executed.
//
Procedure BeforeImportType(Container, MetadataObject, Cancel) Export
	
	If UsersServiceSaaSSTLReUse.RecordSetListWithReferencesToUsers().Get(MetadataObject) <> Undefined Then
		
		SavedRefsToUnspecifiedUser = New ValueTable();
		
		For Each Dimension IN MetadataObject.Dimensions Do
			
			SavedRefsToUnspecifiedUser.Columns.Add(Dimension.Name, Dimension.Type);
			
		EndDo;
		
	Else
		
		SavedRefsToUnspecifiedUser = Undefined;
		
	EndIf;
	
EndProcedure

Procedure BeforeObjectImport(Container, Object, Artifacts, Cancel) Export
	
	If TypeOf(Object) = Type("CatalogObject.Users") Then
		
		// Users catalog
		
		InitialUnspecifiedUser = False;
		
		For Each Artifact IN Artifacts Do
			
			If Artifact.Type() = TypeArtifactUnseparatedUser() Then
				
				InternalName = Artifact.UserName;
				ID = ServiceUserIdentifierByInternalName(InternalName);
				
				If UsersServiceSaaSSTL.UserRegisteredAsUnseparated(ID) Then
					
					Object.InfobaseUserID = ID;
					Object.Description = UsersServiceSaaSSTL.FullNameOfServiceUser(ID);
					
				EndIf;
				
			ElsIf Artifact.Type() = ArtifactTypeUnspecifiedUser() Then
				
				InitialUnspecifiedUser = True;
				
			EndIf;
			
		EndDo;
		
		If Object.Ref.UUID() = UnspecifiedUserCurrentIdentifier AND Not InitialUnspecifiedUser Then
			Cancel = True;
		EndIf;
		
	ElsIf UsersServiceSaaSSTLReUse.RecordSetListWithReferencesToUsers().Get(Object.Metadata()) <> Undefined Then
		
		// Set recordset containing dimension with type CatalogRef Users
		
		CollapseUsersRefsInSet(Object);
		
	Else
		
		Raise ServiceTechnologyIntegrationWithSSL.PlaceParametersIntoString(
			NStr("en='Metadata object% 1 can not be processed by handler ServiceUsersInBTCSaaS.BeforeObjectImport().';ru='Объект метаданных %1 не может быть обработан обработчиком ПользователиСлужебныйВМоделиСервисаБТС.ПередЗагрузкойОбъекта()!'"),
			Object.Metadata().FullName());
		
	EndIf;
	
EndProcedure

#EndRegion

#EndRegion

//

#Region ServiceProceduresAndFunctions

Function UnspecifiedUserIdentifierDataExportType()
	
	Return "1cfresh\ApplicationData\DefaultUserRef";
	
EndFunction

Function TypeArtifactUnseparatedUser() Export
	
	Return XDTOFactory.Type(Package(), "UnseparatedUser");
	
EndFunction

Function ArtifactTypeUnspecifiedUser()
	
	Return XDTOFactory.Type(Package(), "UndefinedUser");
	
EndFunction

Function Package()
	
	Return "http://www.1c.ru/1cFresh/Data/Artefacts/ServiceUsers/1.0.0.1";
	
EndFunction

Function UnseparatedUserInternalName(Val ID)
	
	Manager = InformationRegisters.UnseparatedUsers.CreateRecordManager();
	Manager.InfobaseUserID = ID;
	Manager.Read();
	If Manager.Selected() Then
		Return Manager.UserName;
	Else
		Return "";
	EndIf;
	
EndFunction

Function ServiceUserIdentifierByInternalName(Val InternalName)
	
	QueryText =
		"SELECT
		|	UnseparatedUsers.InfobaseUserID AS InfobaseUserID
		|FROM
		|	InformationRegister.UnseparatedUsers AS UnseparatedUsers
		|WHERE
		|	UnseparatedUsers.UserName = &UserName";
	Query = New Query(QueryText);
	Query.SetParameter("UserName", InternalName);
	QueryResult = Query.Execute();
	If QueryResult.IsEmpty() Then
		Return New UUID("00000000-0000-0000-0000-000000000000");
	Else
		Selection = QueryResult.Select();
		Selection.Next();
		Return Selection.InfobaseUserID;
	EndIf;
	
EndFunction

Procedure CollapseUsersRefsInSet(RecordSet)
	
	RefsUnspecifiedUser = Catalogs.Users.GetRef(UnspecifiedUserCurrentIdentifier);
	
	ToDeleteRecords = New Array();
	
	For Each Record IN RecordSet Do
		
		FilterStateRows = New Structure();
		
		For Each Dimension IN RecordSet.Metadata().Dimensions Do
			
			VerifiedValue = Record[Dimension.Name];
			
			If ValueIsFilled(VerifiedValue) Then
				
				If TypeOf(VerifiedValue) = Type("CatalogRef.Users") Then
					
					If VerifiedValue = RefsUnspecifiedUser Then
						
						FilterStateRows.Insert(Dimension.Name, VerifiedValue);
						
					EndIf;
					
				EndIf;
				
			EndIf;
			
		EndDo;
		
		If FilterStateRows.Count() > 0 Then
			
			If SavedRefsToUnspecifiedUser.FindRows(FilterStateRows).Count() = 0 Then
				
				StateString = SavedRefsToUnspecifiedUser.Add();
				FillPropertyValues(StateString, Record);
				
			Else
				
				ToDeleteRecords.Add(Record);
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	For Each ToRemoveWrite IN ToDeleteRecords Do
		
		RecordSet.Delete(ToRemoveWrite);
		
	EndDo;
	
EndProcedure

#EndRegion

#EndIf