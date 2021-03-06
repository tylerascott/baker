library(btergm)
library(statnet)
rm(list=ls())
load('Scratch/temp_btergm_null_results.RData')
plot.network(net_list[[2]],displayisolates = FALSE)
?plot.network
net_list[[1]]
test = btergm(net_list[2:10]~edges+isolates+mutual,R=100)
tgof = gof(test,statistic=c(rocpr))
par(mfrow=c(1,1))
?plot
plot(tgof$`Tie prediction`)

plot(net_list[[2]],isolates=FALSE)
lapply(net_list,degreedist)



set.seed(24)
library(lubridate)
library(statnet)
library(btergm)
library(tidyverse)
library(stringr)
Rnum = 1000
Rnum_sim = 100
gwd_sim_reps= 1000
verb.type = 'all'
drop_list = c("Verbs with Predicative Complements")
#drop_list = c('Order Verbs',)

phase_break_date = c(mdy('5/8/2003'),mdy('11/24/2004'),mdy('10/17/2008'),mdy('01/01/2015'))
phase_name = c('planning/scoping','application/settlement development',
               'agency review','license implementation')
phase_break_ddate  = decimal_date(phase_break_date)
period_break_ddates = seq(decimal_date(mdy('05/01/2000')),decimal_date(mdy('11/01/2014')),0.5)


talkers = read_csv('Input/scraped_data/participation_detail.csv')

meeting_master = read_csv('Input/scraped_data/meeting_master.csv')

attendance = read_csv('Input/scraped_data/attendance_summary.csv')

talkers = talkers %>% filter(!is.na(Verb.Type),!Verb.Type %in% drop_list)

#match(paste(talkers$Meeting,talkers$Subject_Match),paste(talkers_summary$Meeting,talkers_summary$Subject_Match))
# verb_in_attendance_names = unlist(lapply(str_to_title(talkers$Verb), 
#                     function(x) any(grepl(paste0(x,'$|','^',x),unique(attendance$Name)))))

#as.data.frame(table(talkers$Verb.Type)) %>% arrange(-Freq)



verb_cats = c('all','Verbs of Communication','Verbs of Creation and Transformation','Verbs of Change of Possession','other')


#talker_list = 
talkers_list = list(talkers %>% filter(!duplicated(paste0(Subject_Match,Meeting))),
                    talkers %>% filter(Verb.Type=='Verbs of Communication') %>% 
                      filter(!duplicated(paste0(Subject_Match,Meeting))),
                    talkers %>% filter(Verb.Type=='Verbs of Creation and Transformation') %>% 
                      filter(!duplicated(paste0(Subject_Match,Meeting))),
                    talkers %>% filter(Verb.Type=='Verbs of Change of Possession') %>% 
                      filter(!duplicated(paste0(Subject_Match,Meeting))),
                    talkers %>% filter(!Verb.Type %in% c('Verbs of Change of Possession','Verbs of Change of Possession','Verbs of Communication')) %>% 
                      filter(!duplicated(paste0(Subject_Match,Meeting))))


meeting_attendees = sort(unique(attendance$Name))
total_people = length(meeting_attendees)
node_base = attendance %>% dplyr::select(-Meeting,-Interval) %>%
  filter(!duplicated(.))
node_base$Agency = ifelse(grepl('USFS|FW|DOE|FERC|UCACE|DOT|NMFS|USDA',node_base$Org),1,0)
node_base$Consultant = ifelse(grepl('Group|Associates|Consult|QEA|Engin',
                                    node_base$Org),1,0)
node_base$Utility = ifelse(grepl('PSE',node_base$Org),1,0)

base_matrix = matrix(0,ncol=total_people,nrow=total_people)
colnames(base_matrix) = rownames(base_matrix) = meeting_attendees


talkers = talkers_list[[1]]
talkers_summary = talkers %>% select(-X1,-X,-Subject) %>% group_by(Meeting,Subject_Match,Interval,Phase,Date,Dec_Date,Year) %>% 
  summarise(part_count = n())
participation_edges = do.call(rbind,lapply(1:nrow(talkers_summary),function(i)
  data.frame(Participant = talkers_summary$Subject_Match[i],Attendee= attendance$Name[attendance$Meeting==talkers_summary$Meeting[i]],
             part_count = talkers_summary$part_count[i],Meeting = talkers_summary$Meeting[i],Year = talkers_summary$Year[i],Date = talkers_summary$Date[i],
             Dec_Date = talkers_summary$Dec_Date[i],Phase = talkers_summary$Phase[i],Interval = talkers_summary$Interval[i])))

interval_engagement_edges = participation_edges %>% group_by(Participant, Attendee,Interval) %>% 
  summarise(direct_engagement = sum(part_count))

net_array = replicate(length(unique(interval_engagement_edges$Interval)),base_matrix)
dimnames(net_array)[[3]] = sort(unique(as.character(interval_engagement_edges$Interval)))
placement = cbind(match(interval_engagement_edges$Participant,meeting_attendees),
                  match(interval_engagement_edges$Attendee,meeting_attendees),
                  match(interval_engagement_edges$Interval,dimnames(net_array)[[3]]))
net_array[placement] = interval_engagement_edges$direct_engagement

net_list = lapply(1:dim(net_array)[3],function(x) 
  as.network(net_array[,,x],directed=T,matrix.type='adjacency'))

interval_attendance = lapply(1:ncol(table(attendance$Name,attendance$Interval)),function(x)
  as.data.frame.matrix(table(attendance$Name,attendance$Interval)[,replicate(nrow(table(attendance$Name,attendance$Interval)),x)],
                       dimnames=list(rownames(table(attendance$Name,attendance$Interval)),
                                     rownames(table(attendance$Name,attendance$Interval)))))
for (i in 1:length(interval_attendance))
{colnames(interval_attendance[[i]]) =  rownames(table(attendance$Name,attendance$Interval))}

interval_attendance_prior = interval_attendance[-length(interval_attendance)]
interval_attendance_prior= lapply(interval_attendance_prior,as.matrix)
interval_attendance_prior = lapply(interval_attendance_prior,sqrt)

interval_outdegree = apply(net_array,3,rowSums)
#lapply(1:ncol(yearly_outdegree),function(x) as.data.frame.matrix()
interval_outdegree = lapply(1:ncol(interval_outdegree),function(i)
  cbind(replicate(nrow(interval_outdegree),interval_outdegree[,i])))
for (i in 1:length(interval_outdegree)){colnames(interval_outdegree[[i]]) = 
  rownames(interval_outdegree[[i]])}
interval_outdegree_prior = interval_outdegree[-length(interval_outdegree)]
interval_outdegree_prior = lapply(interval_outdegree_prior,sqrt)

interval_outdegree_x_attendance_prior = lapply(1:length(interval_outdegree_prior),function(x) interval_outdegree_prior[[x]]*
                                                 interval_attendance_prior[[x]])

dynamic_list = lapply(1:dim(net_array)[3],function(x) base_matrix)
for (mat in 2:length(net_list))
{
  dynamic_list[[mat]] <- ifelse(as.sociomatrix(net_list[[mat-1]])>0,1,-1)
}
dynamic_list_prior = dynamic_list[-dim(net_array)[3]]

stability_list = lapply(1:dim(net_array)[3],function(x) base_matrix)
for (mat in 2:length(net_list))
{
  stability_list[[mat]] <- ifelse(as.sociomatrix(net_list[[mat-1]])>0,1,0)
}
stability_list_prior = stability_list[-dim(net_array)[3]]


for (x in 1:length(net_list))
{
  network::set.vertex.attribute(net_list[[x]],attrname = 'High_Resource',
                                value = rowSums(node_base[match(network.vertex.names(net_list[[x]]),node_base$Name),
                                                          c('Agency','Utility','Consultant')]))
}

require(igraph)
coreness_metric_list = lapply(1:length(net_list),function(x)
  graph.coreness(graph_from_adjacency_matrix(as.sociomatrix(net_list[[x]]))))

for (x in 2:length(net_list))
{
  network::set.vertex.attribute(net_list[[x]],attrname = 'Core_Order_Prior',
                                value = coreness_metric_list[[x-1]][
                                  match(network.vertex.names(net_list[[x]]),names(coreness_metric_list[[x-1]]))])
}

for (x in 2:length(net_list))
{
  network::set.vertex.attribute(net_list[[x]],
                                value = network::get.vertex.attribute(net_list[[x]],'High_Resource') *
                                  network::get.vertex.attribute(net_list[[x]],'Core_Order_Prior'),
                                attrname = 'High_Resource_x_Core_Order_Prior')}

for (x in 2:length(net_list))
{
  network::set.vertex.attribute(net_list[[x]],attrname = 'Utility',
                                value = ifelse(network::network.vertex.names(net_list[[x]]) %in% node_base$Name[node_base$Utility==1],1,0))
}


node_base$Mandatory = ifelse(grepl("NMFS|USFS|WDOE",node_base$Org),1,0)

for (x in 2:length(net_list))
{
  network::set.vertex.attribute(net_list[[x]],attrname = 'Mandatory',
                                value = ifelse(network::network.vertex.names(net_list[[x]]) %in% node_base$Name[node_base$Mandatory==1],1,0))
}

node_base$Mandatory_or_Util = ifelse(grepl("NMFS|USFS|WDOE",node_base$Org)|node_base$Utility==1,1,0)

for (x in 2:length(net_list))
{
  network::set.vertex.attribute(net_list[[x]],attrname = 'Mandatory_or_Util',
                                value = ifelse(network::network.vertex.names(net_list[[x]]) %in% node_base$Name[node_base$Mandatory_or_Util==1],1,0))
}


for (x in 2:length(net_list))
{
  network::set.vertex.attribute(net_list[[x]],attrname = 'High_Core',
                                value = ifelse(network::get.vertex.attribute(net_list[[x]],'Core_Order_Prior')>=10,1,0))}

for (x in 2:length(net_list))
{
  network::set.vertex.attribute(net_list[[x]],value = network::get.vertex.attribute(net_list[[x]],'High_Resource') *
                                  network::get.vertex.attribute(net_list[[x]],'High_Core'),
                                attrname = 'High_Resource_x_High_Core')}


utility_matrix_odegree = do.call(cbind,lapply(1:network::network.size(net_list[[2]]),function(x) network::get.vertex.attribute(net_list[[2]],'Utility')))
utility_list_odegree  = lapply(1:length(net_list),function(x) utility_matrix_odegree)
utility_matrix_idegree = do.call(rbind,lapply(1:network::network.size(net_list[[2]]),function(x) network::get.vertex.attribute(net_list[[2]],'Utility')))
utility_list_idegree  = lapply(1:length(net_list),function(x) utility_matrix_idegree)
utility_list_odegree = utility_list_odegree[-1] 
utility_list_idegree = utility_list_idegree[-1]


# signatory_matrix_odegree = do.call(cbind,lapply(1:network.size(net_list[[2]]),function(x) get.vertex.attribute(net_list[[2]],'Signatory')))
# signatory_list_odegree  = lapply(1:length(net_list),function(x) signatory_matrix_odegree)
# 
# signatory_matrix_idegree = do.call(rbind,lapply(1:network.size(net_list[[2]]),function(x) get.vertex.attribute(net_list[[2]],'Signatory')))
# signatory_list_idegree  = lapply(1:length(net_list),function(x) signatory_matrix_idegree)
# 
# signatory_list_odegree = signatory_list_odegree[-1] 
# signatory_list_idegree = signatory_list_idegree[-1]

gwid_decay = gwod_decay = 2
gwesp_decay = 2

form0A = net_list[-1] ~ edges  + mutual + isolates + gwidegree(gwid_decay,fixed=T) +  
  #gwodegree(gwod_decay,fixed=T) +
  gwesp(gwesp_decay,fixed=T) + timecov(transform = function(t) t)
form0B = net_list[-1] ~ edges  + mutual + isolates + gwidegree(gwid_decay,fixed=T) +  
  #gwodegree(gwod_decay,fixed=T) + 
  gwesp(gwesp_decay,fixed=T) + timecov(transform = function(t) t) + timecov(transform = function(t) t^2)
form0C = net_list[-1] ~ edges  + mutual + isolates + gwidegree(gwid_decay,fixed=T) +  
  #gwodegree(gwod_decay,fixed=T) + 
  gwesp(gwesp_decay,fixed=T) + timecov(transform = function(t) t)+ timecov(transform = function(t) t^2)+ timecov(transform = function(t) t^3)



networks <- list()
for(i in 1:10){
  mat <- matrix(rbinom(100, 1, .25), nrow = 10, ncol = 10)
  diag(mat) <- 0
  nw <- network(mat)
  networks[[i]] <- nw
}

covariates <- list()
for (i in 1:10) {
  mat <- matrix(rnorm(100), nrow = 10, ncol = 10)
  covariates[[i]] <- mat
}

fit <- btergm(networks ~ edges + istar(2) + edgecov(covariates) 
              + timecov(transform = function(t) t) 
              + timecov(transform = function(t) t^2)
              + timecov(covariates, transform = function(t) t)
              + timecov(covariates, transform = function(t) t^2), R = 100)

fit2 = btergm(net_list[-1] ~ edges + isolates,R = 100)
test2 = gof(fit2,statistic=c(rocpr))
net_list[[10]]
tt = ergm(net_list[[10]] ~ edges + isolates + gwesp(0.25,fixed=T))
ff = gof(tt,statistic=c(rocpr))
plot(test2)

par(mfrow=c(1,1))
plot(test$`Tie prediction`)



