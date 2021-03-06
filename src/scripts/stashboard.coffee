# Description:
#   Allows Hubot to read and write status changes on stashboard.
#
# Dependencies:
#   oauth-lite
#   url
#   request
#
# Configuration:
#   HUBOT_STASHBOARD_TOKEN
#   HUBOT_STASHBOARD_SECRET
#   HUBOT_STASHBOARD_URL
#
# Commands:
#   hubot stashboard (status|?) - Display current stashboard status (via stupid hipchat icons)
#   hubot stashboard set <service> <status> <message> - Set <service> to <status> with description <message>
#
# Urls:
#
#  http://www.stashboard.org/
#
# Author:
#   rsalmond

urllib = require 'url'
oauth = require 'oauth-lite'
request = require 'request'

class Stashbot
    #hipchat icons, customize away
    status_up: ['(awyeah)', '(content)', '(freddie)', '(fuckyeah)', '(goodnews)', '(thumbsup)', '(successful)', '(success)',
    '(yey)']
    status_down: ['(boom)', '(cerealspit)', '(jackie)', '(ohcrap)', '(omg)', '(poo)', '(rageguy)', '(thumbsdown)', '(tableflip)',
    '(wtf)']
    status_warn:  ['(dumb)', '(derp)', '(embarassed)', '(facepalm)', '(grumpycat)', '(okay)', '(oops)', '(pokerface)', '(sadpanda)',
     '(shrug)', '(sadtroll)', '(wat)']

    constructor: (@robot, cb) ->
        if process.env.HUBOT_STASHBOARD_URL? and process.env.HUBOT_STASHBOARD_TOKEN? and process.env.HUBOT_STASHBOARD_SECRET?
            @state =
                oauth_consumer_key: 'anonymous'
                oauth_consumer_secret: 'anonymous'
                oauth_token: process.env.HUBOT_STASHBOARD_TOKEN
                oauth_token_secret: process.env.HUBOT_STASHBOARD_SECRET
            @base_url = process.env.HUBOT_STASHBOARD_URL
        else
            cb 'Please set environment variables.'

    get_status_all: (cb) ->
        request.get @base_url + '/services', (error, data, response) =>
            if err?
                return cb('Unable to retrieve status. ERROR: ' + err)

            if data.statusCode != 200
                return cb('Unable to retrieve status. HTTP: ' + data.statusCode)

            status = JSON.parse response
            for service in status.services
                service_msg = service.name + ' '
                switch service['current-event'].status.id
                    when 'down' then service_msg += @status_down[Math.floor(Math.random() * @status_down.length)]
                    when 'up' then  service_msg += @status_up[Math.floor(Math.random() * @status_up.length)]
                    when 'warn' then service_msg += @status_warn[Math.floor(Math.random() * @status_warn.length)]
                cb(null, service_msg)

    set_status: (search_string, status, message, cb) ->
        found = false
        request.get @base_url + "/services", (error, data, response) =>
            if response?
                services = JSON.parse response
                for service in services['services']
                    do (service) =>
                        if (service.id.search search_string.toLowerCase()) > -1
                            found = true
                            form = status: status, message: message
                            options = urllib.parse(@base_url + '/services/' + service.id + '/events')
                            options.url = options
                            options.method = 'POST'
                            headers = 'Authorization': oauth.makeAuthorizationHeader(@state, options)
                            request.post url: options.url, form: form, headers: headers, (error, data, response) =>
                                return cb('Okay, service ' + service.name + ' marked as ' + status + ' due to ' + message)
                unless found
                    cb('Unable to find service service called: ' + search_string)

module.exports = (robot) ->

    stashbot = new Stashbot robot, (err) ->
        robot.send null, 'Stashbot init error: ' + err

    robot.respond /stashboard (status|\?)/i, (msg) =>
        msg.send 'Checking stashboard status ...'
        stashbot.get_status_all (err, status_msg) ->
            unless err?
                msg.send status_msg
            else
                msg.send err

    robot.respond /stashboard set (.*?) (.*?) (.*)/i, (msg) =>
        stashbot.set_status msg.match[1], msg.match[2], msg.match[3], (data) ->
            msg.send data
