# ali-commons
AliCloud module with common functionality

## Finding an image

aliyun ecs DescribeImages --ImageOwnerAlias "system" --OSType "linux" --PageNumber 1 --PageSize 100 | jq -r '.Images .Image[] .ImageName'
