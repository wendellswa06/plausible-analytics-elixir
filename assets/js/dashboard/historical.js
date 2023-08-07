import React from 'react';

import Datepicker from './datepicker'
import SiteSwitcher from './site-switcher'
import Filters from './filters'
import CurrentVisitors from './stats/current-visitors'
import VisitorGraph from './stats/graph/visitor-graph'
import Sources from './stats/sources'
import Pages from './stats/pages'
import Locations from './stats/locations';
import Devices from './stats/devices'
import Behaviours from './stats/behaviours'
import ComparisonInput from './comparison-input'
import { withPinnedHeader } from './pinned-header-hoc';
import { statsBoxClass } from '.';

function Historical(props) {
  const tooltipBoundary = React.useRef(null)

  return (
    <div className="mb-12">
      <div id="stats-container-top"></div>
      <div className={`relative top-0 sm:py-3 py-2 z-10 ${props.stuck && !props.site.embedded ? 'sticky fullwidth-shadow bg-gray-50 dark:bg-gray-850' : ''}`}>
        <div className="items-center w-full flex">
          <div className="flex items-center w-full" ref={tooltipBoundary}>
            <SiteSwitcher site={props.site} loggedIn={props.loggedIn} currentUserRole={props.currentUserRole} />
            <CurrentVisitors site={props.site} query={props.query} lastLoadTimestamp={props.lastLoadTimestamp} tooltipBoundary={tooltipBoundary.current} />
            <Filters className="flex" site={props.site} query={props.query} history={props.history} />
          </div>
          <Datepicker site={props.site} query={props.query} />
          <ComparisonInput site={props.site} query={props.query} />
        </div>
      </div>
      <VisitorGraph site={props.site} query={props.query} />

      <div className="w-full md:flex">
        <div className={ statsBoxClass }>
          <Sources site={props.site} query={props.query} />
        </div>
        <div className={ statsBoxClass }>
          <Pages site={props.site} query={props.query} />
        </div>
      </div>

      <div className="w-full md:flex">
        <div className={ statsBoxClass }>
          <Locations site={props.site} query={props.query} />
        </div>
        <div className={ statsBoxClass }>
          <Devices site={props.site} query={props.query} />
        </div>
      </div>

      <Behaviours site={props.site} query={props.query} currentUserRole={props.currentUserRole} />
    </div>
  )
}

export default withPinnedHeader(Historical, '#stats-container-top');
