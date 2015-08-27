/* source: http://a33ik.blogspot.com/2011/11/crm-2011-reports-on-data-auditing.html */
Declare @attributes VarChar(Max), @values VarChar(Max), @ObjectTypeCode int, @LogDateTime DateTime, @RecordId uniqueidentifier, @UserId Uniqueidentifier, @ActionId int

Declare @Result Table(AttributeId int, Value VarChar(Max), ObjectTypeCode int, LogDateTime DateTime, RecordId uniqueidentifier, UserId uniqueidentifier, ActionId int)
Declare @CurrentAttribute VarChar(max), @CurrentValue VarChar(Max)

DECLARE DataAuditCursor CURSOR FOR 
Select 
    Case When IsNull(a.AttributeMask, '') = '' Then '' Else Substring(a.AttributeMask, 2, Len(a.AttributeMask) - 2) End
    ,a.ChangeData
    ,a.ObjectTypeCode
    ,a.CreatedOn
    ,a.ObjectId
    ,a.UserId
    ,a.[Action]
From Audit a
OPEN DataAuditCursor

FETCH NEXT FROM DataAuditCursor 
INTO @attributes, @values, @ObjectTypeCode, @LogDateTime, @RecordId, @UserId, @ActionId

WHILE @@FETCH_STATUS = 0
BEGIN
    WHILE CHARINDEX(',',@attributes,0) <> 0
    BEGIN
        SELECT
            @CurrentAttribute=RTRIM(LTRIM(SUBSTRING(@attributes,1,CHARINDEX(',',@attributes,0)-1))),
            @attributes=RTRIM(LTRIM(SUBSTRING(@attributes,CHARINDEX(',',@attributes,0)+1,LEN(@attributes)))),
            @CurrentValue=RTRIM(LTRIM(SUBSTRING(@values,1,CHARINDEX('~',@values,0)-1))),
            @values=RTRIM(LTRIM(SUBSTRING(@values,CHARINDEX('~',@values,0)+1,LEN(@values))))
     
        IF LEN(@CurrentAttribute) > 0
            INSERT INTO @Result Values(CAST(@CurrentAttribute as int), @CurrentValue, @ObjectTypeCode, @LogDateTime, @RecordId, @UserId, @ActionId)
    END

    INSERT INTO @Result Values((Case When IsNull(@attributes, '') = '' Then Null Else CAST(@attributes as int) End), @values, @ObjectTypeCode, @LogDateTime, @RecordId, @UserId, @ActionId) 

    FETCH NEXT FROM DataAuditCursor 
    INTO @attributes, @values, @ObjectTypeCode, @LogDateTime, @RecordId, @UserId, @ActionId
END

CLOSE DataAuditCursor;
DEALLOCATE DataAuditCursor;
 
Select 
    (Select Top 1 Name From MetadataSchema.Entity e Where r.ObjectTypeCode = e.ObjectTypeCode) EntityName
    ,(Select Top 1 a.Name From MetadataSchema.Attribute a 
    Inner Join MetadataSchema.Entity e On a.EntityId = e.EntityId and a.ColumnNumber = r.AttributeId and e.ObjectTypeCode = r.ObjectTypeCode) AttributeName
    ,u.fullname UserName
    ,r.Value OldFieldValue
    ,r.RecordId ModifiedRecordId
From @Result r
    Left Join FilteredSystemUser u On r.UserId = u.systemuserid
