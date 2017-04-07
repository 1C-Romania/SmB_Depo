///////////////////////////////////////////////////////////////////////////////////
// SaaSReUse.
//
///////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Returns array of serializable structural types supported now.
//
// Returns:
// Fixed map of elements type Type.
//
Function StructuralTypesToSerialize() Export
	
	TypeArray = New Array;
	
	TypeArray.Add(Type("Structure"));
	TypeArray.Add(Type("FixedStructure"));
	TypeArray.Add(Type("Array"));
	TypeArray.Add(Type("FixedArray"));
	TypeArray.Add(Type("Map"));
	TypeArray.Add(Type("FixedMap"));
	TypeArray.Add(Type("KeyAndValue"));
	TypeArray.Add(Type("ValueTable"));
	
	Return New FixedArray(TypeArray);
	
EndFunction

// Returns the end point for sending messages to service manager.
//
// Returns:
//  ExchangePlanRef.MessageExchange - node corresponding to the service manager.
//
Function ServiceManagerEndPoint() Export
	
	SetPrivilegedMode(True);
	Return Constants.ServiceManagerEndPoint.Get();
	
EndFunction

// Returns match of user contact information kinds to kinds.
// CI of used in XDTO service model.
//
// Returns:
//  Map - CI kinds match.
//
Function AccordanceOfUserCITypesXDTO() Export
	
	Map = New Map;
	Map.Insert(Catalogs.ContactInformationKinds.UserEmail, "UserEMail");
	Map.Insert(Catalogs.ContactInformationKinds.UserPhone, "UserPhone");
	
	Return New FixedMap(Map);
	
EndFunction

// Returns match of contact information kinds to XDTO kinds.
// User CI.
//
// Returns:
//  Map - CI kinds match.
//
Function AccordanceCIXDTOTypesToUserCI() Export
	
	Map = New Map;
	For Each KeyAndValue IN SaaSReUse.AccordanceOfUserCITypesXDTO() Do
		Map.Insert(KeyAndValue.Value, KeyAndValue.Key);
	EndDo;
	
	Return New FixedMap(Map);
	
EndFunction

// Returns XDTO rights match used in the service
// model to possible actions in the service model.
// 
// Returns:
//  Map - match rights to actions.
//
Function AccordanceRightXDTOUserActionsService() Export
	
	Map = New Map;
	Map.Insert("ChangePassword", "ChangePassword");
	Map.Insert("ChangeName", "ChangeName");
	Map.Insert("ChangeDescriptionFull", "ChangeDescriptionFull");
	Map.Insert("ChangeAccess", "ChangeAccess");
	Map.Insert("ChangeAdmininstrativeAccess", "ChangeAdmininstrativeAccess");
	
	Return New FixedMap(Map);
	
EndFunction

// Returns data model description corresponding to data area.
//
// Returns:
//  FixedMap,
//    Key - MetadataObject,
//    Value - String, name of the general attribute separator.
//
Function GetDataAreaModel() Export
	
	Result = New Map();
	
	MainDataSeparator = CommonUseReUse.MainDataSeparator();
	MainAreaData = CommonUseReUse.SeparatedMetadataObjects(
		MainDataSeparator);
	For Each MainDataAredElement IN MainAreaData Do
		Result.Insert(MainDataAredElement.Key, MainDataAredElement.Value);
	EndDo;
	
	SupportDataSplitter = CommonUseReUse.SupportDataSplitter();
	AuxilaryDataOfArea = CommonUseReUse.SeparatedMetadataObjects(
		SupportDataSplitter);
	For Each AuxilaryDataElementOfArea IN AuxilaryDataOfArea Do
		Result.Insert(AuxilaryDataElementOfArea.Key, AuxilaryDataElementOfArea.Value);
	EndDo;
	
	Return New FixedMap(Result);
	
EndFunction

#EndRegion
