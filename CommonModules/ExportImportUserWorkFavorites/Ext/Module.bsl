////////////////////////////////////////////////////////////////////////////////
// Subsystem "Data export import".
//
////////////////////////////////////////////////////////////////////////////////

#Region DataExportImportHandlersRegistration

// It is called on the registration of the arbitrary handlers of data export.
//
// Parameters: HandlersTable - ValueTable, in
//  this procedure it is required to supplement this
//  table of values with information about registered random export data handlers. Columns:
//    MetadataObject - MetadataObject, when exporting
//      the data of which the registered handler must be called,
//     Handler - GeneralModule, a general module in
//      which random handler of the data export implemented. Set of export procedures
//      that must be implemented in the handler, depends on
//      the set values of the following table columns,
//     Version - String - Interface version number of exporting/importing
//      data handlers, supported by handler,
//     BeforeExportType - Boolean, a flag showing that a handler is to be called before exporting all the infobase objects that are associated with the metadata object. If the True value is set - in the general module
//      of a handler, exported procedure
//      BeforeExportType() must be implemented, that supports the following parameters:
//        Container - DataProcessorObject.DataExportImportContainerManager - container manager that is used in the process of data export. See more
//          the review to the application data processor interface DataExportImportContainerManager, 
//        Serializer - XDTOSerializer, initiated with support of references abstracts execution. If a random exporting handler requires additional data export - You
//          should use SerializerXDTO that is passed to
//          the procedure BeforeExportType() as the parameter value of Serializer rather
//          than received by using the global context properties SerializerXDTO, 
//        MetadataObject - MetadataObject before exporting
//          data of which the handler was called, 
//        Cancel - Boolean. If in the BeforeExportType() procedure set this parameter as True - exporting
//          of objects corresponding to the current metadata object will not be executed.
//    BeforeObjectExport - Boolean, a flag showing that it is required to call a handler before exporting a particular object of the infobase. If the
//      True value is set - in the general module of a handler, exported
//      procedure BeforeObjectExport() must be implemented that supports the following parameters:
//        Container - DataProcessorObject.DataExportImportContainerManager - container manager that is used in the process of data export. See more
//          the review to the application data processor interface DataExportImportContainerManager,
//         ExportObjectManager - DataProcessorObject.DataExportImportInfobaseDataExportManager -
//          Manager of the current object export. See more the review to the
//          application data processor interface    DataExportImportInfobaseDataExportManager. The parameter is passed only on the call of the handler procedures for which version higher than 1.0.0.1 is specified on registration,
//        Serializer - XDTOSerializer, initiated with support of references abstracts execution. If a random exporting handler requires additional data export - You
//          should use SerializerXDTO that is passed to
//          the procedure BeforeObjectExport() as the parameter value of Serializer rather
//          than received by using the global context properties SerializerXDTO,
//         Object - ConstantValueManager.*,
//          CatalogObject.*, DocumentObject.*, BusinessProcessObject.*, TaskObject.*,
//          ChartOfAccountsObject.*, ExchangePlanObject.*, ChartOfCharacteristicTypesObject.*,
//          ChartOfCalculationTypesObject.*, InformationRegisterRecordSet.*,
//          AccumulationRegisterRecordSet.*, AccountingRegisterRecordSet.*, CalculationRegisterRecordSet.*, SequenceRecordSet.*, RecalculationRecordSet.* -
//          data object of the info base before exporting of which the handler was called.
//          Value that is passed to the BeforeObjectExport() procedure as the Object parameter value can be modified within the BeforeObjectExport() processor, made changes will be shown in the object serialization of export files, but will not be recorded in the infobase 
//        Artifacts- Array(XDTOObject) - Set additional information logically
//          connected inextricably with the object but not not being his part artifacts object). Artifacts
//          should formed inside handler BeforeObjectExport() and added
//          to the array passed as parameter values Artifacts. Each artifact must be the XDTOobject for which type, as the base type, abstract XDTOtype is used {http://www.1c.ru/1cFresh/Data/Dump/1.0.2.1}Artefact. It is
//          allowed to use XDTOpackages in addition to the originally supplied content DataExportImport subsystem. Further
//          artifacts that are formed in the procedure BeforeObjectExport(), will
//          be available in handlers procedures of data import (see review for the procedure WhenDataImportHandlersRegistration().
//        Cancel - Boolean. If you set True for the parameter in procedure BeforeObjectExport()- object export for which the
//           handler was called will not be executed.
//    AfterExportType() - Boolean, a flag showing that a handler is to be called after exporting all objects of the infobase that belongs to that metadata object. If the
//      True value is set - in a general module of the handler, exported procedure AfterExportType() must be implemented that supports the following parameters:
//        Container - DataProcessorObject.DataExportImportContainerManager - container manager that is used in the process of data export. See more
//          the review to the application data processor interface DataExportImportContainerManager,
//        Serializer - XDTOSerializer, initiated with support of references abstracts execution. If a random exporting handler requires additional data export - You
//          should use SerializerXDTO that is passed to
//          the procedure AfterExportType() as the parameter value of Serializer rather
//          than received  by using the global context properties SerializerXDTO, 
//        MetadataObject - MetadataObject, after exporting
//          data of which the handler was called.
//
Procedure WhenDataImportHandlersRegistration(HandlersTable) Export
	
	NewHandler = HandlersTable.Add();
	NewHandler.Handler = ExportImportUserWorkFavorites;
	NewHandler.BeforeExportSettings = True;
	NewHandler.Version = DataExportImportServiceEvents.HandlersVersion1_0_0_1();
	
EndProcedure

// It is called on registering the data import arbitrary handlers.
//
// Parameters: HandlersTable - ValueTable, in
//  this procedure it is required to supplement this
//  table of values with information about registered random import data handlers. Columns:
//    MetadataObject - MetadataObject, when importing
//      the data of which the registered handler must be called, 
//    Handler - CommonModule, a common module in which a random handler of the data import is implemented. Set of export procedures
//      that must be implemented in the handler, depends on
//      the set values of the following table columns, 
//    Version - String - Interface version number of exporting/importing
//      data handlers, supported by handler
//    BeforeMatchRefs - Boolean, a flag showing that a handler is to be called before matching the references 
//      (in original and current IB) that belong to the metadata object. If the True value is set - in a general module of the handler,
//      exported procedure BeforeMatchRefs() must be implemented that supports the following parameters:
//        Container - DataProcessorObject.DataExportImportContainerManager - manager
//          of a container that is used in the data import process. For more information, see a comment to the DataExportImportContainerManager application interface processor.
//        MetadataObject - MetadataObject before mapping the references of which the handler was called, 
//        StandardProcessor - Boolean. If procedure
//          BeforeMatchRefs() install that False parameter value instead of
//          standard mathcing refs (search of objects in the current IB with
//          the same natural key values, that were exported
//          from the IBsource) function MatchRefs() will be
//          called of general module, in the procedure BeforeMatchRefs() which the value parameter
//          StandardProcessing  was set to False.
//          MatchRefs() function parameters:
//            Container - DataProcessorObject.DataExportImportContainerManager - manager
//              of a container that is used in the data import process. See more
//              the review to the application processing interface DataExportImportContainerManager,
//            SourceLinksTable - ValueTable, that contains information about the refs exported from the original IB. Columns:
//                SourceRef - AnyRef, object ref of original IB,
//                  which is required to be mapped with the ref of current IB,
//                Remaining columns of equal fields of natural object key that were passed to
//                  the DataExportImportInfobase.RequiredMatchRefsOnImport() function during data export
//          MatchRefs() function return value - ValueTable, columns:
//            SourceRef - AnyReference, object refs, exported from the original IB,
//            Refs - AnyRef mapped with the original reference in current IB.
//        Cancel - Boolean. If you set True for the parameter in procedure BeforeMatchRefs() - mapping of the references corresponding to the current metadata object will not be executed.
//    BeforeImportType - Boolean, the flag showing the necessity to call the handler before importing all data objects that belong to that metadata object. If the True value is set - in a general module of the handler, exported procedure BeforeImportType() must be implemented that supports the following parameters:
//        Container - DataProcessorObject.DataExportImportContainerManager - manager of a container that is used in the data import process. 
//         For more information, see a comment to the DataExportImportContainerManager application interface processor.
//        MetadataObject - MetadataObject, before importing
//          all data of which the handler was called,
//        Cancel - Boolean. If you set True for the parameter in procedure BeforeImportType()- all data objects corresponding to the current metadata object will not be imported.
//    BeforeObjectImport - Boolean, the flag showing the necessity to call the handler before importing the data object that belongs to that metadata object. If the True value is set - in a general module of the handler, the BeforeObjectImport() exported procedure must be implemented supporting the parameters as follows:
//        Container - DataProcessorObject.DataExportImportContainerManager - manager of a container that is used in the data import process. 
//          For more information, see a comment to the DataExportImportContainerManager application interface processor.
//        Object - ConstantValueManager.*,
//          CatalogObject.*, DocumentObject.*, BusinessProcessObject.*, TaskObject.*,
//          ChartOfAccountsObject.*, ExchangePlanObject.*, ChartOfCharacteristicTypesObject.*,
//          ChartOfCalculationTypesObject.*, InformationRegisterRecordSet.*,
//          AccumulationRegisterRecordSet.*, AccountingRegisterRecordSet.*, CalculationRegisterRecordSet.*, SequenceRecordSet.*, RecalculationRecordSet.* -
//          data object of the info base before importing of which the handler was called.
//          Value that is passed to procedure BeforeObjectImport() as the Object parameter value can be modified within the handler procedure BeforeObjectImport().
//        Artifacts - Array(XDTOObject) - additional data that
//          is logically inextricably associated with the data object, but not being a part of it. 
//          Created in exported procedures BeforeObjectExport() of data export handlers (see a comment to procedure
//          OnDataExportHandlersRegistration(). Each artifact must be the XDTOobject for which type, as the base type, 
//          abstract XDTOtype is used {http://www.1c.ru/1cFresh/Data/Dump/1.0.2.1}Artefact. It is
//          allowed to use XDTOpackages in addition to the originally supplied content DataExportImport subsystem.
//        Cancel - Boolean. If you install this parameter value to True in the BeforeObjectImport() procedure- Import of the data object will not be executed.
//    AftertObjectImport - Boolean, the flag showing the necessity to call the handler after importing the data object that belongs to that metadata object. If the True value is set - in a general module of the handler, the AftertObjectImport() exported procedure must be implemented supporting the parameters as follows:
//        Container - DataProcessorObject.DataExportImportContainerManager - manager
//          of a container that is used in the data import process. For more information, see a comment to the DataExportImportContainerManager application interface processor.
//        Object - ConstantValueManager.*,
//          CatalogObject.*, DocumentObject.*, BusinessProcessObject.*, TaskObject.*,
//          ChartOfAccountsObject.*, ExchangePlanObject.*, ChartOfCharacteristicTypesObject.*,
//          ChartOfCalculationTypesObject.*, InformationRegisterRecordSet.*,
//          AccumulationRegisterRecordSet.*, AccountingRegisterRecordSet.*, CalculationRegisterRecordSet.*, SequenceRecordSet.*, RecalculationRecordSet.* -
//          data object of the info base after importing of which the handler was called.
//        Artifacts - Array(XDTOObject) - additional data that
//          is logically inextricably associated with the data object, but not being part of it. Created in exported procedures BeforeObjectExport() of data export handlers (see a comment to procedure OnDataExportHandlersRegistration(). Each artifact must be the XDTOobject for which type, as the base type, abstract XDTOtype is used {http://www.1c.ru/1cFresh/Data/Dump/1.0.2.1}Artefact. It is
//          allowed to use XDTOpackages in addition to the originally supplied content DataExportImport subsystem.
//    AfterImportType - Boolean, the flag showing the necessity to call the handler after importing all data objects that belong to that metadata object. If the True value is set - in a general module of the handler, the AfterImportType() exported procedure must be implemented supporting the parameters as follows:
//        Container - DataProcessorObject.DataExportImportContainerManager - manager of a container that is used in the data import process. 
//          For more information, see a comment to the DataExportImportContainerManager application interface processor.
//        MetadataObject - MetadataObject, after importing
//          all objects of which the handler was called.
//
Procedure WhenDataExportHandlersRegistration(HandlersTable) Export
	
	NewHandler = HandlersTable.Add();
	NewHandler.Handler = ExportImportUserWorkFavorites;
	NewHandler.BeforeLoadSettings = True;
	NewHandler.Version = DataExportImportServiceEvents.HandlersVersion1_0_0_1();
	
EndProcedure

#EndRegion

#Region DataExportImportHandlers

Procedure BeforeExportSettings(Container, Serializer, SettingsStorageName, SettingsKey, ObjectKey, Settings, User, Presentation, Artifacts, Cancel) Export
	
	If TypeOf(Settings) = Type("UserWorkFavorites") Then
		
		For Each FavItem IN Settings Do
			
			NewArtifact = XDTOFactory.Create(FavItemArtifactType());
			NewArtifact.Important = FavItem.Important;
			NewArtifact.URL = DisplayNavigationRefInArtifact(FavItem.URL);
			NewArtifact.Presentation = FavItem.Presentation;
			
			Artifacts.Add(NewArtifact);
			
		EndDo;
		
		Settings = New UserWorkFavorites();
		
	EndIf;
	
EndProcedure

Procedure BeforeLoadSettings(Container, SettingsStorageName, SettingsKey, ObjectKey, Settings, User, Presentation, Artifacts, Cancel) Export
	
	If TypeOf(Settings) = Type("UserWorkFavorites") Then
		
		For Each Artifact IN Artifacts Do
			
			If Artifact.Type() = FavItemArtifactType() Then
				
				NewItem = New UserWorkFavoritesItem();
				NewItem.Important = Artifact.Important;
				NewItem.URL = NavigationRefOnDisplayingInArtifact(Artifact.URL);
				NewItem.Presentation = Artifact.Presentation;
				
				Settings.Add(NewItem);
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

Function NavigationRefOnDisplayingInArtifact(Val Representation)
	
	Result = Representation.Template;
	
	If Representation.MainRef <> Undefined Then
		
		Key = Representation.MainRef.Key;
		Refs = Representation.MainRef.Value;
		
		Result = StrReplace(Result, String(Key) + ".Type", Refs.Metadata().FullName());
		Result = StrReplace(Result, String(Key) + ".UUID",
			UUIDDisplayToNavigationRefFormat(Refs.UUID()));
		
	EndIf;
	
	For Each DisplayAdditionalRef IN Representation.AdditionalRef Do
		
		Key = DisplayAdditionalRef.Key;
		Refs = DisplayAdditionalRef.Value;
		
		TypeRow = CommonUse.TypePresentationString(TypeOf(Refs));
		IdentificatorRow = UUIDDisplayToNavigationRefFormat(Refs.UUID());
		
		If DisplayAdditionalRef.RequreTypeAnnotition Then
			
			LookupString = TypeRow + ":" + IdentificatorRow;
			
		Else
			
			LookupString = IdentificatorRow;
			
		EndIf;
		
		LookupString = EncodeString(LookupString, StringEncodingMethod.URLEncoding);
		
		Result = StrReplace(Result, String(Key) + ".UUID", LookupString);
		
	EndDo;
	
	RefStructure = NavigationRefStructure(Result);
	
	Result = RefStructure.Protocol + "/" + RefStructure.Type;
	
	If ValueIsFilled(RefStructure.Path) Then
		Result = Result + "/" + RefStructure.Path;
	EndIf;
	
	If ValueIsFilled(RefStructure.Parameters) Then
		Result = Result + "?" + RefStructure.Parameters;
	EndIf;
	
	Return Result;
	
EndFunction

Function DisplayNavigationRefInArtifact(Val URL)
	
	Representation = XDTOFactory.Create(TypeDisplayNavigationRefInArtifact());
	Representation.Template = URL;
	
	RefStructure = NavigationRefStructure(URL);
	
	If ThisIsNavigationRefToInfobaseObject(RefStructure) Then
		
		RefStructure.Parameters = RefStructure.Parameters;
		
		MetadataObject = MetadataObjectOnPathToNavigationRef(RefStructure.Path);
		
		If MetadataObject <> Undefined Then
			
			If CommonUseSTL.ThisIsReferenceData(MetadataObject) Then
				
				Key = New UUID();
				
				Representation.MainRef = XDTOFactory.Create(RefDisplayTypeToArtifact());
				Representation.MainRef.Key = Key;
				
				Representation.Template = StrReplace(Representation.Template, MetadataObject.FullName(), String(Key) + ".Type");
				
			EndIf;
			
			RefsInParameters = RefsInNavigationRefParameters(RefStructure.Parameters, MetadataObject);
			
			For Each String IN RefsInParameters Do
				
				Representation.Template = StrReplace(Representation.Template, String.InitialSubstring, String.DecodedSubstring);
				
				If String.ParameterName = "ref" Then
					
					Representation.MainRef.Value = XDTOSerializer.WriteXDTO(String.Ref);
					Representation.MainRef.RequreTypeAnnotition = String.RequiredAnnotationTypeInNavigationRef;
					Representation.Template = StrReplace(Representation.Template, String.RefSubstring, String(Key) + ".UUID");
					
				Else
					
					Key = New UUID();
					
					DisplayAdditionalRef = XDTOFactory.Create(RefDisplayTypeToArtifact());
					DisplayAdditionalRef.Key = Key;
					DisplayAdditionalRef.Value = XDTOSerializer.WriteXDTO(String.Ref);
					DisplayAdditionalRef.RequreTypeAnnotition = String.RequiredAnnotationTypeInNavigationRef;
					
					Representation.AdditionalRef.Add(DisplayAdditionalRef);
					
					Representation.Template = StrReplace(Representation.Template, String.RefSubstring, String(Key) + ".UUID");
					
				EndIf;
				
			EndDo;
			
		EndIf;
		
	EndIf;
	
	Return Representation;
	
EndFunction

Function ThisIsNavigationRefToInfobaseObject(Val NavigationRefStructure)
	
	If NavigationRefStructure.Protocol = "e1cib" AND NavigationRefStructure.Type = "data" Then // Not localized
		Return True;
	Else
		Return False;
	EndIf;
	
EndFunction

Function NavigationRefStructure(Val URL)
	
	Result = New Structure("Protocol, Type, Path, Parameters", "", "", "", "");
	
	RefSubstrings = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(URL, "/");
	
	If RefSubstrings.Count() >= 1 Then
		Result.Protocol = RefSubstrings[0];
	EndIf;
	
	If RefSubstrings.Count() >= 2 Then
		Result.Type = RefSubstrings[1];
	EndIf;
	
	If RefSubstrings.Count() >= 3 Then
		
		Body = RefSubstrings[2];
		
		SeparatorPosition = Find(Body, "?");
		
		If SeparatorPosition = 0 Then
			
			Result.Path = Body;
			Result.Parameters = "";
			
		Else
			
			Result.Path = Left(Body, SeparatorPosition - 1);
			Result.Parameters = StrReplace(Body, Result.Path + "?", "");
			
		EndIf;
		
	EndIf;
	
	Return Result;
	
EndFunction

Function MetadataObjectOnPathToNavigationRef(Val PathString)
	
	PathStructure = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(PathString, ".");
	
	If PathStructure.Count() >= 2 Then
		
		Return Metadata.FindByFullName(PathStructure[0] + "." + PathStructure[1]);
		
	EndIf;
	
	Return Undefined;
	
EndFunction

Function RefsInNavigationRefParameters(Val ParameterString, Val MetadataObject)
	
	Result = New ValueTable();
	Result.Columns.Add("InitialSubstring", New TypeDescription("String"));
	Result.Columns.Add("DecodedSubstring", New TypeDescription("String"));
	Result.Columns.Add("ParameterName", New TypeDescription("String"));
	Result.Columns.Add("Ref", CommonUseSTLReUse.ReferenceTypeDescription());
	Result.Columns.Add("RefSubstring", New TypeDescription("String"));
	Result.Columns.Add("RequiredAnnotationTypeInNavigationRef", New TypeDescription("Boolean"));
	
	Substrings = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(ParameterString, "&");
	
	For Each Substring IN Substrings Do
		
		SeparatorPosition = Find(Substring, "=");
		
		FieldName = Left(Substring, SeparatorPosition - 1);
		FieldValue = StrReplace(Substring, FieldName + "=", "");
		
		If CommonUseSTL.ThisIsReferenceData(MetadataObject) AND FieldName = "ref" Then
			
			Manager = CommonUse.ObjectManagerByFullName(MetadataObject.FullName());
			RefUUID = UUIDFromDisplayInNavigationRefFormat(FieldValue);
			Refs = Manager.GetRef(RefUUID);
			
			ResultRow = Result.Add();
			ResultRow.InitialSubstring = Substring;
			ResultRow.DecodedSubstring = Substring;
			ResultRow.ParameterName = "ref";
			ResultRow.Ref = Refs;
			ResultRow.RefSubstring = FieldValue;
			ResultRow.RequiredAnnotationTypeInNavigationRef = False;
			
		ElsIf CommonUseSTL.ThisIsRecordSet(MetadataObject) Then
			
			FieldSourceValue = FieldValue;
			FieldValue = DecodeString(FieldValue, StringEncodingMethod.URLEncoding);
			
			DimensionField = MetadataObject.Dimensions.Find(FieldName);
			
			PossibleTypesCount = ReferenceTypesCountInTypeDescription(DimensionField.Type);
			
			If PossibleTypesCount = 1 Then
				
				RequiredAnnotationTypeInNavigationRef = False;
				IdentificatorRow = IdentificatorRowFromDisplayInNavigationRefFormat(FieldValue);
				
				If StringFunctionsClientServer.ThisIsUUID(IdentificatorRow) Then
					
					EmptyRef = New(DimensionField.Type.Types()[0]);
					Manager = CommonUse.ObjectManagerByFullName(EmptyRef.Metadata().FullName());
					
					RefUUID = New UUID(IdentificatorRow);
					Refs = Manager.GetRef(RefUUID);
					
				Else
					
					Continue;
					
				EndIf;
				
			ElsIf PossibleTypesCount > 1 Then
				
				RequiredAnnotationTypeInNavigationRef = True;
				DelimiterPositionType = Find(FieldValue, ":");
				
				If DelimiterPositionType > 0 Then
					
					TypeName = Left(FieldValue, DelimiterPositionType - 1);
					IdentificatorRow = IdentificatorRowFromDisplayInNavigationRefFormat(
						StrReplace(FieldValue, TypeName + ":", ""));
					
					If StringFunctionsClientServer.ThisIsUUID(IdentificatorRow) Then
						
						EmptyRef = New(Type(TypeName));
						Manager = CommonUse.ObjectManagerByFullName(EmptyRef.Metadata().FullName());
						
						RefUUID = New UUID(IdentificatorRow);
						Refs = Manager.GetRef(RefUUID);
						
					Else
						
						Continue;
						
					EndIf;
					
				Else
					
					Continue;
					
				EndIf;
				
			Else
				
				Continue;
				
			EndIf;
			
			ResultRow = Result.Add();
			ResultRow.InitialSubstring = Substring;
			ResultRow.DecodedSubstring = StrReplace(Substring, FieldSourceValue, FieldValue);
			ResultRow.ParameterName = FieldName;
			ResultRow.Ref = Refs;
			ResultRow.RefSubstring = FieldValue;
			ResultRow.RequiredAnnotationTypeInNavigationRef = RequiredAnnotationTypeInNavigationRef;
			
		EndIf;
		
	EndDo;
	
	Return Result;
	
EndFunction

Function ReferenceTypesCountInTypeDescription(Val TypeDescription)
	
	Result = 0;
	
	For Each Type IN TypeDescription.Types() Do
		
		If Not CommonUseSTL.IsPrimitiveType(Type) Then
			
			Result = Result + 1;
			
		EndIf;
		
	EndDo;
	
	Return Result;
	
EndFunction

Function UUIDDisplayToNavigationRefFormat(Val ID)
	
	RefIdentifier = String(ID);
	
	Return Mid(RefIdentifier, 20, 4)
		+ Mid(RefIdentifier, 25)
		+ Mid(RefIdentifier, 15, 4)
		+ Mid(RefIdentifier, 10, 4)
		+ Mid(RefIdentifier, 1, 8);
	
EndFunction

Function UUIDFromDisplayInNavigationRefFormat(Val Representation)
	
	IdentificatorRow = IdentificatorRowFromDisplayInNavigationRefFormat(Representation);
	Return New UUID(IdentificatorRow);
	
EndFunction

Function IdentificatorRowFromDisplayInNavigationRefFormat(Val Representation)
	
	FirstPart    = Mid(Representation, 25, 8);
	SecondPart    = Mid(Representation, 21, 4);
	ThirdPart    = Mid(Representation, 17, 4);
	FourthPart = Mid(Representation, 1,  4);
	FifthPart     = Mid(Representation, 5,  12);
	
	Return FirstPart + "-" + SecondPart + "-" + ThirdPart + "-" + FourthPart + "-" + FifthPart;
	
EndFunction

Function FavItemArtifactType()
	
	Return XDTOFactory.Type(Package(), "FavoriteItemArtefact");
	
EndFunction

Function TypeDisplayNavigationRefInArtifact()
	
	Return XDTOFactory.Type(Package(), "URL");
	
EndFunction

Function RefDisplayTypeToArtifact()
	
	Return XDTOFactory.Type(Package(), "URLRef");
	
EndFunction

Function Package()
	
	Return "http://www.1c.ru/1cFresh/Data/Artefacts/UserWorkFavorites/1.0.0.1";
	
EndFunction

#EndRegion
