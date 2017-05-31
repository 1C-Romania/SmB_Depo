Function GetAllRefsTypeDescription() Export
	AllRefsTypeDescription = Catalogs.AllRefsType();
	AllRefsTypeDescription = New TypeDescription(AllRefsTypeDescription, Documents.AllRefsType().Types());
	AllRefsTypeDescription = New TypeDescription(AllRefsTypeDescription, ChartsOfCharacteristicTypes.AllRefsType().Types());
	AllRefsTypeDescription = New TypeDescription(AllRefsTypeDescription, ExchangePlans.AllRefsType().Types());
	AllRefsTypeDescription = New TypeDescription(AllRefsTypeDescription, ChartsOfCalculationTypes.AllRefsType().Types());
	AllRefsTypeDescription = New TypeDescription(AllRefsTypeDescription, ChartsOfAccounts.AllRefsType().Types());
	AllRefsTypeDescription = New TypeDescription(AllRefsTypeDescription, Enums.AllRefsType().Types());
	AllRefsTypeDescription = New TypeDescription(AllRefsTypeDescription, BusinessProcesses.AllRefsType().Types());
	AllRefsTypeDescription = New TypeDescription(AllRefsTypeDescription, Tasks.AllRefsType().Types());
	Return AllRefsTypeDescription;
EndFunction

Function GetStandartsObjectAttributes() Export
	AttributesInfo = New Structure;
	AttributesInfo.Insert("ObjectMetadataName", New Structure("Type", New TypeDescription("String")));
	AttributesInfo.Insert("ObjectTitle", New Structure("Type", New TypeDescription("String")));
	AttributesInfo.Insert("NewRef", New Structure("Type", GetAllRefsTypeDescription()));
	AttributesInfo.Insert("HeaderAttributes", New Structure("Type", New TypeDescription("Undefined")));
	AttributesInfo.Insert("FormInformation", New Structure("Type", New TypeDescription("Undefined")));
	AttributesInfo.Insert("FormOwnerUUID", New Structure("Type", New TypeDescription("String")));
	AttributesInfo.Insert("HeaderValue", New Structure("Type", New TypeDescription("Undefined")));
	AttributesInfo.Insert("PrefixList", New Structure("Type", New TypeDescription("ValueList")));
	AttributesInfo.Insert("ShowNumberPreview", New Structure("Type", New TypeDescription("Boolean")));
	Return New FixedStructure(AttributesInfo);
EndFunction